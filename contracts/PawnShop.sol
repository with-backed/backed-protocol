pragma solidity 0.8.6;

import './interfaces/IERC20.sol';
import './interfaces/IPawnLoans.sol';
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import './descriptors/PawnShopNFTDescriptor.sol';

import "hardhat/console.sol";

struct PawnTicket {
    // ==== immutable =====
    address loanAsset;
    address collateralAddress;
    uint256 collateralID;
    // ==== mutable ======
    uint256 perBlockInterestRate;
    // used to track loanAsset amount of interest accumulated, incase of interest rate change
    uint256 accumulatedInterest;
    // at which block was the accumulated interest most recently calculated
    uint256 lastAccumulatedInterestBlock;
    uint256 blockDuration;
    uint256 loanAmount;
    uint256 loanAmountDrawn;
    bool closed;
    bool collateralSeized;
}

contract NFTPawnShop is ERC721Enumerable {
    // ==== Immutable 
    // i.e. 1e18 = 1 = 100%
    uint8 public immutable interestRateDecimals = 18;
    // i.e. 10 ** interestRateDecimals
    uint256 public immutable SCALAR = 1e18;

    address private immutable _tokenDescriptor;

    // ==== Mutable 
    mapping(uint256 => PawnTicket) public ticketInfo;
    uint256 private _nonce;
    // paybacks to claim
    // pawnticket => address => balance
    mapping(uint256 => mapping(address => uint256)) private _loanPaymentBalances;
    // ERC721, each token represents a loan corresponding in ID to a PawnTicket
    address public loansContract;

    address public manager;
    // 5% to start
    uint128 public pawnShopTakeRate = 5 * 1e16;
    // ERC20 address => value
    mapping(address => uint256) public cashDrawer;

    // ==== modifiers
    modifier managerOnly() { 
        require(msg.sender == manager, "NFTPawnShop: manager only");
        _; 
    }

    modifier ticketExists(uint256 ticketID) { 
        require(ticketID <= _nonce, "NFTPawnShop: pawn ticket does not exist");
        _; 
    }

    // ==== view ====
    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        return  PawnShopNFTDescriptor(_tokenDescriptor).ticketURI(this, tokenId);
    }

    function totalOwed(uint256 pawnTicketID) ticketExists(pawnTicketID) view public returns (uint256) {
        return ticketInfo[pawnTicketID].loanAmountDrawn + interestOwed(pawnTicketID);
    }

    function lenderInterestRateAfterPawnShopTake(uint256 interestRate) view public returns (uint256) {
        return interestRate * (SCALAR - pawnShopTakeRate) / SCALAR ;
    }

    function lendeeInterestRateAfterPawnShopTake(uint256 interestRate) view public returns (uint256) {
        return interestRate * SCALAR / (SCALAR - pawnShopTakeRate);
    }

    function interestOwed(uint256 pawnTicketID) ticketExists(pawnTicketID) view public returns (uint256) {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        return totalInterestedOwned(ticket, ticket.perBlockInterestRate);
    }

    function interestOwedToLender(uint256 pawnTicketID) ticketExists(pawnTicketID) view public returns (uint256) {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        return totalInterestedOwned(ticket, lenderInterestRateAfterPawnShopTake(ticket.perBlockInterestRate));
    }

    // NOTE: we calculate using current block.sub(start block).sub(1), to exclude 
    // both the start block and the current block from the interst 
    function totalInterestedOwned(PawnTicket storage ticket, uint256 interestRate) private view returns (uint256) {
        if(ticket.closed || ticket.lastAccumulatedInterestBlock == 0){
            return 0;
        }
        return ticket.loanAmount
            * (block.number - ticket.lastAccumulatedInterestBlock - 1)
            * interestRate
            / SCALAR
            + ticket.accumulatedInterest; //.add(ticket.accumulatedInterest);
    }

    function drawableBalance(uint256 pawnTicketID) ticketExists(pawnTicketID) view external returns (uint256) {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        if(ticket.closed){
            return 0;
        }
        return ticket.loanAmount - ticket.loanAmountDrawn;
    }

    function loanEndBlock(uint256 pawnTicketID) ticketExists(pawnTicketID) view external returns (uint256) {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        return ticket.blockDuration + ticket.lastAccumulatedInterestBlock;
    }

    function loanPaymentBalance(uint256 pawnTicketID, address account) ticketExists(pawnTicketID) view public returns (uint256) {
        return _loanPaymentBalances[pawnTicketID][account];
    }

    constructor(address _manager, address _tokenDescriptor_) ERC721("Pawn Tickets", "PWNT") {
        manager = _manager;
        _tokenDescriptor = _tokenDescriptor_;
    }

    // ==== state changing
    function mintPawnTicket(
        uint256 nftID,
        address nftAddress,
        uint256 maxInterest,
        uint256 minAmount,
        address loanAsset,
        uint256 minBlocks
        ) external returns(uint256 id) {
        id = ++_nonce;
        PawnTicket storage ticket = ticketInfo[id];
        IERC721(nftAddress).transferFrom(msg.sender, address(this), nftID);
        ticket.loanAsset = loanAsset;
        ticket.loanAmount = minAmount;
        ticket.collateralID = nftID;
        ticket.collateralAddress = nftAddress;
        ticket.perBlockInterestRate = maxInterest;
        ticket.blockDuration = minBlocks;
        _safeMint(msg.sender, id, "");
    }

    // for closing a ticket and getting item back 
    // before it has a loan
    function closeTicket(uint256 pawnTicketID) ticketExists(pawnTicketID) external {
        require(ownerOf(pawnTicketID) == msg.sender, "NFTPawnShop: must be owner of pawned item");
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        require(ticket.lastAccumulatedInterestBlock == 0, "NFTPawnShop: has loan, use repayAndCloseTicket");
        IERC721(ticket.collateralAddress).transferFrom(address(this), ownerOf(pawnTicketID), ticket.collateralID);
        ticket.closed = true;
    }

    // loan money, agreeing to pawn ticket terms or better
    // replaces existing loan, if there is one and the terms qualify 
    function underwritePawnLoan(uint256 pawnTicketID, uint256 interest, uint256 blockDuration, uint256 amount) ticketExists(pawnTicketID) external {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        uint256 effectiveInterestRate = lenderInterestRateAfterPawnShopTake(ticket.perBlockInterestRate);
        require(effectiveInterestRate >= interest && ticket.blockDuration <= blockDuration && ticket.loanAmount <= amount, "NFTPawnShop: Proposed terms do not qualify" );
        uint256 accumulatedInterest = 0;
        if(ticket.lastAccumulatedInterestBlock != 0){
            // someone already has this loan, to replace them, the offer must improve
            require(ticket.loanAmount < amount || ticket.blockDuration < blockDuration || effectiveInterestRate > interest, "NFTPawnShop: proposed terms must be better than existing terms");
            // we only want to add the interest for blocks that this account held the loan
            // i.e. since last accumulatedInterest
            // we do not include current block in the interest calculation. It will also not 
            // be included in the next interest calculation. Blocks when a loan is bought out are 
            // interest free :-) 
            accumulatedInterest = ticket.loanAmount
                * (block.number - ticket.lastAccumulatedInterestBlock - 1)
                * effectiveInterestRate //.mul(interestRate)
                / SCALAR;
            // account acquiring this loan needs to transfer amount + interest so far
            IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), amount + accumulatedInterest);
            address currentLoanOwner = IERC721(loansContract).ownerOf(pawnTicketID);
            // we add to exisiting balance here incase this person has owned this loan before
            _loanPaymentBalances[pawnTicketID][currentLoanOwner] = _loanPaymentBalances[pawnTicketID][currentLoanOwner] + accumulatedInterest + ticket.loanAmount; 
            IPawnLoans(loansContract).transferLoan(currentLoanOwner, msg.sender, pawnTicketID);
        } else {
            IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), amount);
            IPawnLoans(loansContract).mintLoan(msg.sender, pawnTicketID);
        }
        // interest rate in the struct is always the lendees rate,
        // what is paid to the lowner owner has the pawn shop take removed
        ticket.perBlockInterestRate = lendeeInterestRateAfterPawnShopTake(interest);
        ticket.accumulatedInterest = ticket.accumulatedInterest + accumulatedInterest;
        ticket.lastAccumulatedInterestBlock = block.number;
        ticket.blockDuration = blockDuration;
        ticket.loanAmount = amount;
    }

    function drawLoan(uint256 pawnTicketID, uint256 amount) ticketExists(pawnTicketID) external {
        require(ownerOf(pawnTicketID) == msg.sender, "NFTPawnShop: must be owner of pawned item");
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        // we do not want to allow the lendee to close the loan and then draw again
        // but if the loan was closed be seizing collateral, then lendee should still be able 
        // to draw the full amount
        require(!ticket.closed || ticket.collateralSeized, "NFTPawnShop: ticket closed");
        ticket.loanAmountDrawn = ticket.loanAmountDrawn + amount;
        IERC20(ticket.loanAsset).transfer(msg.sender, amount);
    }

    function repayAndCloseTicket(uint256 pawnTicketID) ticketExists(pawnTicketID) external {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        uint256 interest = interestOwed(pawnTicketID);
        IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), interest + ticket.loanAmountDrawn);
        address loanOwner = IERC721(loansContract).ownerOf(pawnTicketID);
        uint256 pawnShopTake = interest * pawnShopTakeRate / SCALAR;
        _loanPaymentBalances[pawnTicketID][loanOwner] = loanPaymentBalance(pawnTicketID, loanOwner) + interest - pawnShopTake + ticket.loanAmount;
        cashDrawer[ticket.loanAsset] = cashDrawer[ticket.loanAsset] + pawnShopTake;
        ticket.loanAmountDrawn = 0;
        ticket.closed = true;
        IERC721(ticket.collateralAddress).transferFrom(address(this), ownerOf(pawnTicketID), ticket.collateralID);
    }

    function seizeCollateral(uint256 pawnTicketID) ticketExists(pawnTicketID) external {
        PawnTicket storage ticket = ticketInfo[pawnTicketID];
        require(!ticket.closed, "NFTPawnShop: ticket closed");
        require(block.number > ticket.blockDuration + ticket.lastAccumulatedInterestBlock, "NFTPawnShop: payment is not late");
        IERC721(ticket.collateralAddress).transferFrom(address(this), IERC721(loansContract).ownerOf(pawnTicketID), ticket.collateralID);
        ticket.closed = true;
        ticket.collateralSeized = true;
    }

    function withdrawLoanPayment(uint256 pawnTicketID, uint256 amount) ticketExists(pawnTicketID) external {
        _loanPaymentBalances[pawnTicketID][msg.sender] = loanPaymentBalance(pawnTicketID, msg.sender) - amount;
        IERC20(ticketInfo[pawnTicketID].loanAsset).transfer(msg.sender, amount);
    }

    // === manger state changing

    function setPawnLoansContract(address _contract) managerOnly external {
        require(loansContract == address(0), 'NFTPawnShop: already set');
        loansContract = _contract;
    }

    function withdrawFromCashDrawer(address asset, uint256 amount, address to) managerOnly external {
        cashDrawer[asset] = cashDrawer[asset] - amount;
        IERC20(asset).transfer(to, amount);
    }

    function updateManager(address _manager) managerOnly external {
        manager = _manager;
    }

    function updatePawnShopTakeRate(uint128 _takeRate) managerOnly external {
        require(_takeRate <= 3 * 1e17, "NFTPawnShop: max take rate 30%");
        pawnShopTakeRate = _takeRate;
    }
}
