pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import './interfaces/IPawnLoans.sol';
import './interfaces/IMintable.sol';
import './descriptors/PawnShopNFTDescriptor.sol';

struct PawnTicket {
    // ==== mutable ======
    bool closed;
    bool collateralSeized;
    uint256 perSecondInterestRate;
    // used to track loanAsset amount of interest accumulated, incase of interest rate change
    uint256 accumulatedInterest;
    // at which block was the accumulated interest most recently calculated
    uint256 lastAccumulatedTimestamp;
    uint256 durationSeconds;
    uint256 loanAmount;
    // ==== immutable =====
    uint256 collateralID;
    address collateralAddress;
    address loanAsset;
    
}

contract NFTPawnShop is Ownable {
    using SafeERC20 for IERC20;

    event MintTicket(uint256 indexed id, address indexed minter, uint256 maxInterestRate, uint256 minLoanAmount, uint256 minDurationSeconds);
    event Close(uint256 indexed id);
    event UnderwriteLoan(uint256 indexed id, address indexed underwriter, uint256 interestRate, uint256 loanAmount, uint256 durationSeconds);
    event BuyoutUnderwriter(uint256 indexed id, address indexed underwriter, address indexed replacedLoanOwner, uint256 interestEarned, uint256 replacedAmount);
    event Repay(uint256 indexed id, address indexed repayer, address indexed loanOwner, uint256 interestEarned, uint256 loanAmount);
    event SeizeCollateral(uint256 indexed id, address indexed to);

    // i.e. 1e11 = 1 = 100%
    uint8 public constant INTEREST_RATE_DECIMALS = 12;
     // i.e. 10 ** INTEREST_RATE_DECIMALS
    uint256 public constant SCALAR = 1e12;


    // 1%
    uint256 public originationFeeRate = 1e10;
    uint256 private _nonce;

    address public loansContract;
    address public ticketsContract;
    address public manager;

    mapping(uint256 => PawnTicket) public ticketInfo;

    // ==== modifiers
    modifier ticketExists(uint256 ticketID) { 
        require(ticketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        _; 
    }

    // ==== view ====
    function totalOwed(uint256 pawnTicketID) ticketExists(pawnTicketID) view external returns (uint256) {
        return ticketInfo[pawnTicketID].loanAmount + interestOwed(pawnTicketID);
    }

    function interestOwed(uint256 pawnTicketID) ticketExists(pawnTicketID) view public returns (uint256) {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        return totalInterestedOwed(ticket, ticket.perSecondInterestRate);
    }

    // NOTE: we calculate using current block.sub(start block).sub(1), to exclude 
    // both the start block and the current block from the interst 
    function totalInterestedOwed(PawnTicket storage ticket, uint256 interestRate) private view returns (uint256) {
        if(ticket.closed || ticket.lastAccumulatedTimestamp == 0){
            return 0;
        }
        
        return ticket.loanAmount
            * (block.timestamp - ticket.lastAccumulatedTimestamp)
            * interestRate
            / SCALAR
            + ticket.accumulatedInterest;
    }

    function loanEndSeconds(uint256 pawnTicketID)  ticketExists(pawnTicketID) view external returns (uint256) {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        return ticket.durationSeconds + ticket.lastAccumulatedTimestamp;
    }

    constructor(address _manager) {
        transferOwnership(_manager);
    }

    // ==== state changing ====
    function mintPawnTicket(
            uint256 nftID,
            address nftAddress,
            uint256 maxInterest,
            uint256 minAmount,
            address loanAsset,
            uint256 minDurationSeconds,
            address mintTo
        ) 
        external 
        returns(uint256 id) 
    {
        id = ++_nonce;
        PawnTicket storage ticket = ticketInfo[id];
        ticket.loanAsset = loanAsset;
        ticket.loanAmount = minAmount;
        ticket.collateralID = nftID;
        ticket.collateralAddress = nftAddress;
        ticket.perSecondInterestRate = maxInterest;
        ticket.durationSeconds = minDurationSeconds;
        IERC721(nftAddress).transferFrom(msg.sender, address(this), nftID);

        IMintable(ticketsContract).mint(mintTo, id);
        emit MintTicket(id, msg.sender, maxInterest, minAmount, minDurationSeconds);
    }

    // for closing a ticket and getting item back 
    // before it has a loan
    function closeTicket(uint256 pawnTicketID, address sendCollateralTo) external {
        require(IERC721(ticketsContract).ownerOf(pawnTicketID) == msg.sender, "NFTPawnShop: must be owner of pawned item");

        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        require(ticket.lastAccumulatedTimestamp == 0, "NFTPawnShop: has loan, use repayAndCloseTicket");
        
        ticket.closed = true;
        IERC721(ticket.collateralAddress).transferFrom(address(this), sendCollateralTo, ticket.collateralID);
        emit Close(pawnTicketID);
    }

    // loan ERC20, agreeing to pawn ticket terms or better
    // replaces existing loan, if there is one and the terms qualify 
    function underwritePawnLoan(
            uint256 pawnTicketID,
            uint256 interestRate,
            uint256 amount,
            uint256 durationSeconds,
            address sendLoanTo
        ) 
        ticketExists(pawnTicketID)
        external 
    {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        require(ticket.perSecondInterestRate >= interestRate && ticket.durationSeconds <= durationSeconds && ticket.loanAmount <= amount, "NFTPawnShop: Proposed terms do not qualify" );

        if(ticket.lastAccumulatedTimestamp == 0){
            IERC20(ticket.loanAsset).safeTransferFrom(msg.sender, address(this), amount);
            uint256 pawnShopTake = amount * originationFeeRate / SCALAR;
            IERC20(ticket.loanAsset).safeTransfer(IERC721(ticketsContract).ownerOf(pawnTicketID), amount - pawnShopTake);
            IMintable(loansContract).mint(sendLoanTo, pawnTicketID);
        } else {
            uint256 amountIncrease = amount - ticket.loanAmount;
            require((ticket.loanAmount * 10 / 100) <= amountIncrease || ticket.durationSeconds + (ticket.durationSeconds * 10 / 100) <= durationSeconds || ticket.perSecondInterestRate - (ticket.perSecondInterestRate * 10 / 100) >= interestRate, "NFTPawnShop: proposed terms must be better than existing terms");

            uint256 accumulatedInterest = totalInterestedOwed(ticket, ticket.perSecondInterestRate);
            IERC20(ticket.loanAsset).safeTransferFrom(msg.sender, address(this), amount + accumulatedInterest);
            address currentLoanOwner = IERC721(loansContract).ownerOf(pawnTicketID);
            IERC20(ticket.loanAsset).safeTransfer(currentLoanOwner, accumulatedInterest + ticket.loanAmount);
            IPawnLoans(loansContract).pawnShopTransferLoan(currentLoanOwner, sendLoanTo, pawnTicketID);
            if(amountIncrease > 0){
                uint256 pawnShopTake = (amountIncrease * originationFeeRate / SCALAR);
                IERC20(ticket.loanAsset).safeTransfer(IERC721(ticketsContract).ownerOf(pawnTicketID), amount - ticket.loanAmount - pawnShopTake);
            }

            ticket.accumulatedInterest = accumulatedInterest;
            emit BuyoutUnderwriter(pawnTicketID, msg.sender, currentLoanOwner, accumulatedInterest, ticket.loanAmount);
        }
        ticket.perSecondInterestRate = interestRate;
        ticket.lastAccumulatedTimestamp = block.timestamp;
        ticket.durationSeconds = durationSeconds;
        ticket.loanAmount = amount;
        emit UnderwriteLoan(pawnTicketID, msg.sender, interestRate, amount, durationSeconds);
    }

    function repayAndCloseTicket(uint256 pawnTicketID) ticketExists(pawnTicketID) external {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");

        uint256 interest = totalInterestedOwed(ticket, ticket.perSecondInterestRate);
        address loanOwner = IERC721(loansContract).ownerOf(pawnTicketID);
        ticket.closed = true;
        IERC20(ticket.loanAsset).safeTransferFrom(msg.sender, loanOwner, interest + ticket.loanAmount);
        IERC721(ticket.collateralAddress).transferFrom(address(this), IERC721(ticketsContract).ownerOf(pawnTicketID), ticket.collateralID);
        emit Repay(pawnTicketID, msg.sender, loanOwner, interest, ticket.loanAmount);
        emit Close(pawnTicketID);
    }

    function seizeCollateral(uint256 pawnTicketID, address to) external {
        require(IERC721(loansContract).ownerOf(pawnTicketID) == msg.sender, "NFTPawnShop: underwriter only");

        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        require(block.timestamp > ticket.durationSeconds + ticket.lastAccumulatedTimestamp, "NFTPawnShop: payment is not late");

        ticket.closed = true;
        ticket.collateralSeized = true;
        IERC721(ticket.collateralAddress).transferFrom(address(this), to, ticket.collateralID);
        emit SeizeCollateral(pawnTicketID, to);
        emit Close(pawnTicketID);
    }

    // === manger state changing

    function setPawnLoansContract(address _contract) onlyOwner() external {
        require(loansContract == address(0), 'NFTPawnShop: already set');

        loansContract = _contract;
    }

    function setPawnTicketsContract(address _contract) onlyOwner() external {
        require(ticketsContract == address(0), 'NFTPawnShop: already set');

        ticketsContract = _contract;
    }

    function withdrawFromCashDrawer(address asset, uint256 amount, address to) onlyOwner() external {
        IERC20(asset).safeTransfer(to, amount);
    }

    function updateOriginationFeeRate(uint256 _originationFeeRate) onlyOwner() external {
        require(_originationFeeRate <= 5 * (10 ** (INTEREST_RATE_DECIMALS - 2)), "NFTPawnShop: max fee 5%");
        
        originationFeeRate = _originationFeeRate;
    }
}
