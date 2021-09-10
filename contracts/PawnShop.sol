pragma solidity 0.8.6;

import './interfaces/IERC20.sol';
import './interfaces/IPawnLoans.sol';
import './interfaces/IPawnTickets.sol';
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import './descriptors/PawnShopNFTDescriptor.sol';

import "hardhat/console.sol";

struct PawnTicket {
    // ==== mutable ======
    bool closed;
    bool collateralSeized;
    uint256 perBlockInterestRate;
    // used to track loanAsset amount of interest accumulated, incase of interest rate change
    uint256 accumulatedInterest;
    // at which block was the accumulated interest most recently calculated
    uint256 lastAccumulatedInterestBlock;
    uint256 blockDuration;
    uint256 loanAmount;
    uint256 loanAmountDrawn;
    // ==== immutable =====
    uint256 collateralID;
    address collateralAddress;
    address loanAsset;
    
}

contract NFTPawnShop {
    event MintTicket(uint256 indexed id, address indexed minter, uint256 maxInterestRate, uint256 minLoanAmount, uint256 minBlockDuration);
    event Close(uint256 indexed id);
    event UnderwriteLoan(uint256 indexed id, address indexed underwriter, uint256 interestRate, uint256 loanAmount, uint256 blockDuration);
    event BuyoutUnderwriter(uint256 indexed id, address indexed underwriter, address indexed replacedLoanOwner, uint256 interestRate, uint256 loanAmount, uint256 blockDuration, uint256 oldAmount, uint256 interestEarned);
    event DrawLoan(uint256 indexed id, uint256 amount);
    event RepayAndClose(uint256 indexed id, address indexed loanOwner, uint256 interestEarned, uint256 loanAmount);
    event SeizeCollateral(uint256 indexed id);
    event WithdrawRepayment(uint256 indexed id, uint256 amount);

    // i.e. 1e11 = 1 = 100%
    uint8 public constant interestRateDecimals = 11;
    // 1%
    uint256 public originationFeeRate = 1e9;
    // i.e. 10 ** interestRateDecimals
    uint256 public constant SCALAR = 1e11;
    uint256 private _nonce;

    address public loansContract;
    address public ticketsContract;
    address public manager;

    mapping(uint256 => PawnTicket) public ticketInfo;
    mapping(uint256 => mapping(address => uint256)) private _loanPaymentBalances;
    mapping(address => uint256) public cashDrawer;

    // ==== view ====
    function totalOwed(uint256 pawnTicketID) view external returns (uint256) {
        require(pawnTicketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        return ticketInfo[pawnTicketID].loanAmountDrawn + interestOwed(pawnTicketID);
    }

    function interestOwed(uint256 pawnTicketID) view public returns (uint256) {
        require(pawnTicketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        return totalInterestedOwed(ticket, ticket.perBlockInterestRate);
    }

    // NOTE: we calculate using current block.sub(start block).sub(1), to exclude 
    // both the start block and the current block from the interst 
    function totalInterestedOwed(PawnTicket storage ticket, uint256 interestRate) private view returns (uint256) {
        if(ticket.closed || ticket.lastAccumulatedInterestBlock == 0){
            return 0;
        }
        return ticket.loanAmount
            * (block.number - ticket.lastAccumulatedInterestBlock - 1)
            * interestRate
            / SCALAR
            + ticket.accumulatedInterest;
    }

    function drawableBalance(uint256 pawnTicketID) view public returns (uint256) {
        require(pawnTicketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        return (ticket.loanAmount * (SCALAR - originationFeeRate) / SCALAR) - ticket.loanAmountDrawn;
    }

    function loanEndBlock(uint256 pawnTicketID)  view external returns (uint256) {
        require(pawnTicketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        return ticket.blockDuration + ticket.lastAccumulatedInterestBlock;
    }

    function loanPaymentBalance(uint256 pawnTicketID, address account) view public returns (uint256) {
        require(pawnTicketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        return _loanPaymentBalances[pawnTicketID][account];
    }

    constructor(address _manager) {
        manager = _manager;
    }

    // ==== state changing ====
    function mintPawnTicket(
            uint256 nftID,
            address nftAddress,
            uint256 maxInterest,
            uint256 minAmount,
            address loanAsset,
            uint256 minBlocks,
            address mintTo
        ) 
        external 
        returns(uint256 id) 
    {
        id = ++_nonce;
        PawnTicket storage ticket = ticketInfo[id];
        IERC721(nftAddress).transferFrom(msg.sender, address(this), nftID);
        ticket.loanAsset = loanAsset;
        ticket.loanAmount = minAmount;
        ticket.collateralID = nftID;
        ticket.collateralAddress = nftAddress;
        ticket.perBlockInterestRate = maxInterest;
        ticket.blockDuration = minBlocks;

        IPawnTickets(ticketsContract).mintTicket(mintTo, id);
        emit MintTicket(id, msg.sender, maxInterest, minAmount, minBlocks);
    }

    // for closing a ticket and getting item back 
    // before it has a loan
    function closeTicket(uint256 pawnTicketID, address sendCollateralTo) external {
        require(IERC721(ticketsContract).ownerOf(pawnTicketID) == msg.sender, "NFTPawnShop: must be owner of pawned item");
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        require(ticket.lastAccumulatedInterestBlock == 0, "NFTPawnShop: has loan, use repayAndCloseTicket");
        IERC721(ticket.collateralAddress).transferFrom(address(this), sendCollateralTo, ticket.collateralID);
        ticket.closed = true;
        emit Close(pawnTicketID);
    }

    // loan ERC20, agreeing to pawn ticket terms or better
    // replaces existing loan, if there is one and the terms qualify 
    function underwritePawnLoan(
            uint256 pawnTicketID,
            uint256 interestRate,
            uint256 blockDuration,
            uint256 amount,
            address sendLoanTo
        ) 
        external 
    {
        require(pawnTicketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        if(ticket.lastAccumulatedInterestBlock == 0){
            require(ticket.perBlockInterestRate >= interestRate && ticket.blockDuration <= blockDuration && ticket.loanAmount <= amount, "NFTPawnShop: Proposed terms do not qualify" );
            cashDrawer[ticket.loanAsset] = cashDrawer[ticket.loanAsset] + (amount * originationFeeRate / SCALAR);
            IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), amount);
            IPawnLoans(loansContract).mintLoan(sendLoanTo, pawnTicketID);
            emit UnderwriteLoan(pawnTicketID, msg.sender, interestRate, amount, blockDuration);
        } else {
            // someone already has this loan, to replace them, the offer must improve
            require(ticket.loanAmount < amount || ticket.blockDuration < blockDuration || ticket.perBlockInterestRate > interestRate, "NFTPawnShop: proposed terms must be better than existing terms");
            // Only add the interest for blocks that this account held the loan
            // note: blocks when the loan is bought out are interest free
            uint256 accumulatedInterest = ticket.loanAmount
                * (block.number - ticket.lastAccumulatedInterestBlock - 1)
                * ticket.perBlockInterestRate
                / SCALAR;
            // Account acquiring this loan needs to transfer amount + interest so far
            IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), amount + accumulatedInterest);
            address currentLoanOwner = IERC721(loansContract).ownerOf(pawnTicketID);
            // Add to exisiting balance here incase account has owned this loan before
            _loanPaymentBalances[pawnTicketID][currentLoanOwner] += accumulatedInterest + ticket.loanAmount; 
            IPawnLoans(loansContract).transferLoan(currentLoanOwner, sendLoanTo, pawnTicketID);
            cashDrawer[ticket.loanAsset] = cashDrawer[ticket.loanAsset] + ((amount - ticket.loanAmount) * originationFeeRate / SCALAR);
            ticket.accumulatedInterest = ticket.accumulatedInterest + accumulatedInterest;
            emit BuyoutUnderwriter(pawnTicketID, msg.sender, currentLoanOwner, interestRate, amount, blockDuration, accumulatedInterest, ticket.loanAmount);
        }
        ticket.perBlockInterestRate = interestRate;
        ticket.lastAccumulatedInterestBlock = block.number;
        ticket.blockDuration = blockDuration;
        ticket.loanAmount = amount;
    }

    function drawLoan(uint256 pawnTicketID, uint256 amount, address to) external {
        require(IERC721(ticketsContract).ownerOf(pawnTicketID) == msg.sender, "NFTPawnShop: must be owner of pawned item");
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        // can still withdraw if collateral was seized
        require(!ticket.closed || ticket.collateralSeized, "NFTPawnShop: ticket closed");
        require(amount <= ((ticket.loanAmount * (SCALAR - originationFeeRate) / SCALAR) - ticket.loanAmountDrawn), "NFTPawnShop: insufficient balance");
        ticket.loanAmountDrawn = ticket.loanAmountDrawn + amount;
        IERC20(ticket.loanAsset).transfer(to, amount);
        emit DrawLoan(pawnTicketID, amount);
    }

    function repayAndCloseTicket(uint256 pawnTicketID) external {
        require(pawnTicketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        uint256 interest = totalInterestedOwed(ticket, ticket.perBlockInterestRate);
        IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), interest + ticket.loanAmountDrawn);
        address loanOwner = IERC721(loansContract).ownerOf(pawnTicketID);
        _loanPaymentBalances[pawnTicketID][loanOwner] += interest + ticket.loanAmount;
        ticket.loanAmountDrawn = 0;
        ticket.closed = true;
        IERC721(ticket.collateralAddress).transferFrom(address(this), IERC721(ticketsContract).ownerOf(pawnTicketID), ticket.collateralID);
        emit RepayAndClose(pawnTicketID, loanOwner, interest, ticket.loanAmount);
    }

    function seizeCollateral(uint256 pawnTicketID, address to) external {
        require(IERC721(loansContract).ownerOf(pawnTicketID) == msg.sender, "NFTPawnShop: underwriter only");
        require(pawnTicketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        require(block.number > ticket.blockDuration + ticket.lastAccumulatedInterestBlock, "NFTPawnShop: payment is not late");
        IERC721(ticket.collateralAddress).transferFrom(address(this), to, ticket.collateralID);
        ticket.closed = true;
        ticket.collateralSeized = true;
        emit SeizeCollateral(pawnTicketID);
    }

    function withdrawLoanPayment(uint256 pawnTicketID, uint256 amount, address to) external {
        require(pawnTicketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        _loanPaymentBalances[pawnTicketID][msg.sender] = _loanPaymentBalances[pawnTicketID][msg.sender] - amount;
        IERC20(ticketInfo[pawnTicketID].loanAsset).transfer(to, amount);
        emit WithdrawRepayment(pawnTicketID, amount);
    }

    // === manger state changing

    function setPawnLoansContract(address _contract) external {
        require(msg.sender == manager, "NFTPawnShop: manager only");
        require(loansContract == address(0), 'NFTPawnShop: already set');
        loansContract = _contract;
    }

    function setPawnTicketsContract(address _contract) external {
        require(msg.sender == manager, "NFTPawnShop: manager only");
        require(ticketsContract == address(0), 'NFTPawnShop: already set');
        ticketsContract = _contract;
    }

    function withdrawFromCashDrawer(address asset, uint256 amount, address to) external {
        require(msg.sender == manager, "NFTPawnShop: manager only");
        cashDrawer[asset] = cashDrawer[asset] - amount;
        IERC20(asset).transfer(to, amount);
    }

    function updateManager(address _manager) external {
        require(msg.sender == manager, "NFTPawnShop: manager only");
        manager = _manager;
    }

    function updateOriginationFeeRate(uint256 _originationFeeRate) external {
        require(msg.sender == manager, "NFTPawnShop: manager only");
        require(_originationFeeRate <= 5 * (10 ** (interestRateDecimals - 2)), "NFTPawnShop: max fee 5%");
        originationFeeRate = _originationFeeRate;
    }
}
