pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import './interfaces/IPawnLoans.sol';
import './interfaces/IMintable.sol';
import './interfaces/IPawnShop.sol';
import './descriptors/PawnShopNFTDescriptor.sol';
import './interfaces/IERC20Metadata.sol';


struct PawnTicket {
    // ==== mutable ======
    bool closed;
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

contract NFTPawnShop is Ownable, IPawnShop {
    using SafeERC20 for IERC20;

    uint8 public constant override INTEREST_RATE_DECIMALS = 12;
    uint256 public constant override SCALAR = 1 * (10 ** INTEREST_RATE_DECIMALS);

    uint256 public originationFeeRate = 1 * (10 ** (INTEREST_RATE_DECIMALS - 2));
    uint256 private _nonce;

    address public loansContract;
    address public ticketsContract;
    address public manager;

    mapping(uint256 => PawnTicket) public override ticketInfo;

    mapping(address => uint256) public loanAssetMaxAmount;

    // ==== modifiers
    modifier ticketExists(uint256 ticketID) { 
        require(ticketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        _; 
    }

    function isAmountAllowed(address asset, uint256 loanAmount) public returns (bool) {
        return loanAmount <= loanAssetMaxAmount[asset];
    }

    // ==== view ====
    function totalOwed(uint256 pawnTicketID) ticketExists(pawnTicketID) view external returns (uint256) {
        return ticketInfo[pawnTicketID].loanAmount + interestOwed(pawnTicketID);
    }

    function interestOwed(uint256 pawnTicketID) ticketExists(pawnTicketID) view public returns (uint256) {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        return totalInterestedOwed(ticket, ticket.perSecondInterestRate);
    }

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
        require(isAmountAllowed(loanAsset, minAmount), "NFTPawnShop: loan amount too high");

        IERC721(nftAddress).transferFrom(msg.sender, address(this), nftID);

        id = ++_nonce;
        PawnTicket storage ticket = ticketInfo[id];
        ticket.loanAsset = loanAsset;
        ticket.loanAmount = minAmount;
        ticket.collateralID = nftID;
        ticket.collateralAddress = nftAddress;
        ticket.perSecondInterestRate = maxInterest;
        ticket.durationSeconds = minDurationSeconds;
        
        IMintable(ticketsContract).mint(mintTo, id);
        emit MintTicket(id, msg.sender, nftID, nftAddress, maxInterest, loanAsset, minAmount, minDurationSeconds);
    }

    function closeTicket(uint256 pawnTicketID, address sendCollateralTo) external {
        require(IERC721(ticketsContract).ownerOf(pawnTicketID) == msg.sender, "NFTPawnShop: must be owner of pawned item");

        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        require(ticket.lastAccumulatedTimestamp == 0, "NFTPawnShop: underwritten, use repayAndCloseTicket");
        
        ticket.closed = true;
        IERC721(ticket.collateralAddress).transferFrom(address(this), sendCollateralTo, ticket.collateralID);
        emit Close(pawnTicketID);
    }

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
        require(isAmountAllowed(ticket.loanAsset, amount), "NFTPawnShop: loan amount too high");

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
        IERC721(ticket.collateralAddress).transferFrom(address(this), to, ticket.collateralID);
        emit SeizeCollateral(pawnTicketID);
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

    function setLoanAssetMaxAmount(address asset, uint256 amount) onlyOwner() external {
        loanAssetMaxAmount[asset] = amount * (10 ** IERC20Metadata(asset).decimals());
    }
}
