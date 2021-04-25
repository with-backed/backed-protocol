pragma solidity ^0.8.2;

import './interfaces/IERC20.sol';
import './interfaces/IPawnLoans.sol';
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

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
}

contract NFTPawnShop is ERC721Enumerable {

	using SafeMath for uint256;
	// ==== Immutable 
	uint256 private SCALAR = 1e18;

	// ==== Mutable 
	mapping(uint256 => PawnTicket) public pawnTickets;
	uint256 private _nonce;
	// paybacks to claim
	mapping(uint256 => mapping(address => uint256)) private _loanPaymentBalances;
	// ERC721, each token represents a loan corresponding in ID to a PawnTicket
	address public loansContract;

	address public manager;
	// 5% to start
	uint128 public pawnShopTakeRate = 5 * 1e16;
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
	function totalOwed(uint256 pawnTicketID) ticketExists(pawnTicketID) view public returns (uint256) {
		return pawnTickets[pawnTicketID].loanAmountDrawn + interestOwed(pawnTicketID);
	}

	function interestRateAfterPawnShopTake(uint256 interestRate) view public returns (uint256) {
		return interestRate * (SCALAR - pawnShopTakeRate);
	}

	function interestOwed(uint256 pawnTicketID) ticketExists(pawnTicketID) view public returns (uint256) {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		return ticket.loanAmount
			.mul(block.number.sub(ticket.lastAccumulatedInterestBlock))
			.mul(ticket.perBlockInterestRate)
			.div(SCALAR)
			.add(ticket.accumulatedInterest);
	}

	function interestOwnedSinceLastAccumulation(uint256 pawnTicketID) ticketExists(pawnTicketID) view public returns (uint256) {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		return ticket.loanAmount
			.mul(block.number.sub(ticket.lastAccumulatedInterestBlock))
			.mul(ticket.perBlockInterestRate)
			.div(SCALAR)
	}

	function drawableBalance(uint256 pawnTicketID) ticketExists(pawnTicketID) view external returns (uint256) {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		return ticket.loanAmount.sub(ticket.loanAmountDrawn);
	}

	function loanEndBlock(uint256 pawnTicketID) ticketExists(pawnTicketID) view external returns (uint256) {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		return ticket.blockDuration + ticket.lastAccumulatedInterestBlock;
	}

	function loanPaymentBalance(uint256 pawnTicketID) ticketExists(pawnTicketID) view external returns (uint256) {
		return _loanPaymentBalances[pawnTicketID][msg.sender];
	}

	constructor(address _manager) ERC721("Pawn Tickets", "PWNT") {
        manager = _manager;
    }

	// ==== state changing
	function mintPawnTicket(
		uint256 nftID,
		address nftAddress,
		uint256 maxInterest,
		uint256 minAmount,
		address loanAsset,
		uint256 minBlocks
		) external {
		uint256 id = ++_nonce;
		IERC721(nftAddress).transferFrom(msg.sender, address(this), nftID);
		pawnTickets[id] = PawnTicket({
			loanAsset: loanAsset,
			collateralID: nftID,
			collateralAddress: nftAddress,
			perBlockInterestRate: maxInterest,
			accumulatedInterest: 0,
			lastAccumulatedInterestBlock: 0, // this is unset until someone takes the loan
			blockDuration: minBlocks,
			loanAmount: minAmount,
			loanAmountDrawn: 0,
			closed: false
		});
		_safeMint(msg.sender, id, "");
	}

	// loan money, agreeing to pawn ticket terms or better
	// replaces existing loan, if there is one and the terms qualify 
	function underwritePawnLoan(uint256 pawnTicketID, uint256 interest, uint256 blockDuration, uint256 amount) ticketExists(pawnTicketID) external {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		require(interestRateAfterPawnShopTake(ticket.perBlockInterestRate) <= interest, "NFTPawnShop: interest too high");
		require(ticket.blockDuration <= blockDuration, "NFTPawnShop: block duration too low");
		require(ticket.loanAmount <= amount, "NFTPawnShop: amount too low");
		uint256 accumulatedInterest = 0;
		if(ticket.lastAccumulatedInterestBlock != 0){
			// someone already has this loan, to replace them, the offer must improve
			require(ticket.loanAmount < amount || ticket.blockDuration < blockDuration ||
			interestRateAfterPawnShopTake(ticket.perBlockInterestRate) < interest, "NFTPawnShop: loan terms must be better than existing loan");
			// we only want to add the interest for blocks that this account held the loan
			// i.e. since last accumulatedInterest
			accumulatedInterest = interestOwnedSinceLastAccumulation(pawnTicketID);
			// account acquiring this loan needs to transfer amount + interest so far
			IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), amount + accumulatedInterest);
			address currentLoanOwner = IERC721(loansContract).ownerOf(pawnTicketID);
			// we add to exisiting balance here incase this person has owned this loan before
			_loanPaymentBalances[pawnTicketID][currentLoanOwner] = _loanPaymentBalances[pawnTicketID][currentLoanOwner] + interestOwed(pawnTicketID) + ticket.loanAmount; 
			IPawnLoans(loansContract).transferLoan(currentLoanOwner, msg.sender, pawnTicketID);
		} else {
			IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), amount);
			IPawnLoans(loansContract).mintLoan(msg.sender, pawnTicketID);
		}

		pawnTickets[pawnTicketID] = PawnTicket({
			loanAsset: ticket.loanAsset,
			collateralID: ticket.collateralID,
			collateralAddress: ticket.collateralAddress,
			perBlockInterestRate: interest,
			accumulatedInterest: ticket.accumulatedInterest + accumulatedInterest,
			lastAccumulatedInterestBlock: block.number,
			blockDuration: blockDuration,
			loanAmount: amount,
			loanAmountDrawn: ticket.loanAmountDrawn,
			closed: false
		});
	}

	function drawLoan(uint256 pawnTicketID, uint256 amount) ticketExists(pawnTicketID) external {
		require(ownerOf(pawnTicketID) == msg.sender, "NFTPawnShop: must be owner of pawned item");
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		ticket.loanAmount.sub(ticket.loanAmountDrawn).sub(amount, "NFTPawnShop: Insufficient loan balance");
		ticket.loanAmountDrawn = ticket.loanAmountDrawn + amount;
		IERC20(ticket.loanAsset).transfer(msg.sender, amount);
	}

	function repayAndCloseLoan(uint256 pawnTicketID) ticketExists(pawnTicketID) external {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		uint256 interest = interestOwed(pawnTicketID);
		IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), interest + ticket.loanAmountDrawn);
		address loanOwner = IERC721(loansContract).ownerOf(pawnTicketID);
		uint256 loanPaymentBalance = _loanPaymentBalances[pawnTicketID][loanOwner];
		uint256 pawnShopTake = interest * pawnShopTakeRate / SCALAR;
		_loanPaymentBalances[pawnTicketID][loanOwner] = loanPaymentBalance + interest - pawnShopTakeRate + ticket.loanAmount;
		cashDrawer[ticket.loanAsset] = cashDrawer[ticket.loanAsset] + pawnShopTake;
		ticket.closed = true;
		IERC721(ticket.collateralAddress).transferFrom(address(this), ownerOf(pawnTicketID), pawnTicketID);
		IPawnLoans(loansContract).setLoanPaidBack(pawnTicketID);
	}

	function seizeCollateral(uint256 pawnTicketID) ticketExists(pawnTicketID) external {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		require(!ticket.closed, "NFTPawnShop: ticket closed");
		require(block.number > ticket.blockDuration + ticket.lastAccumulatedInterestBlock, "NFTPawnShop: payment is not late");
		IERC721(ticket.collateralAddress).transferFrom(address(this), IERC721(loansContract).ownerOf(pawnTicketID), pawnTicketID);
		ticket.closed = true;
		IPawnLoans(loansContract).setCollateralSeized(pawnTicketID);

	}

	function withdrawLoanPayment(uint256 pawnTicketID, uint256 amount) ticketExists(pawnTicketID) external {
		_loanPaymentBalances[pawnTicketID][msg.sender] = _loanPaymentBalances[pawnTicketID][msg.sender].sub(amount, "NFTPawnShop: Insufficient balance");
		IERC20(pawnTickets[pawnTicketID].loanAsset).transfer(msg.sender, amount);
	}

	// === manger state changing

	function setPawnLoansContract(address _contract) managerOnly external {
		require(loansContract == address(0), 'NFTPawnShop: already set');
		loansContract = _contract;
	}

	function withdrawFromCashDrawer(address asset, uint256 amount, address to) managerOnly external {
		require(cashDrawer[asset] >= amount, "NFTPawnShop: Insufficient funds");
		IERC20(asset).transfer(to, amount);
	}
}
// TODO
// - emit events
// - add our take rate and adjust interest 

// create loan info, mint lockedAsset token
// someone takes on the loan, gets the loan token
// 