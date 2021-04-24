pragma solidity ^0.8.2;

import './interfaces/IERC721Mintable.sol';
import './interfaces/IERC20.sol';
import './interfaces/IERC721AdminTransferable.sol';
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

	function interestOwed(uint256 pawnTicketID) ticketExists(pawnTicketID) view public returns (uint256) {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		return ticket.loanAmount
			.mul(block.number.sub(ticket.lastAccumulatedInterestBlock))
			.mul(ticket.perBlockInterestRate)
			.div(SCALAR)
			.add(ticket.accumulatedInterest);
	}

	function drawableBalance(uint256 pawnTicketID) ticketExists(pawnTicketID) view external returns (uint256) {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		return ticket.loanAmount.sub(ticket.loanAmountDrawn);
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
		require(ticket.perBlockInterestRate <= interest, "NFTPawnShop: interest too high");
		require(ticket.blockDuration <= blockDuration, "NFTPawnShop: block duration too low");
		require(ticket.loanAmount <= amount, "NFTPawnShop: amount too low");
		if(ticket.lastAccumulatedInterestBlock != 0){
			// someone already has this loan, to replace them, the offer must improve
			require(ticket.loanAmount < amount || ticket.blockDuration < blockDuration ||
			ticket.perBlockInterestRate < interest, "NFTPawnShop: loan terms must be better than existing loan");
			uint256 interest = interestOwed(pawnTicketID);
			// account acquiring this loan needs to transfer amount + interest so far
			IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), amount + interest);
			address currentLoanOwner = IERC721(loansContract).ownerOf(pawnTicketID);
			// we add to exisiting balance here incase this person has owned this loan before
			_loanPaymentBalances[pawnTicketID][currentLoanOwner] = _loanPaymentBalances[pawnTicketID][currentLoanOwner] + interestOwed(pawnTicketID) + ticket.loanAmount; 
			IERC721AdminTransferable(loansContract).adminTransferFrom(currentLoanOwner, msg.sender, pawnTicketID);
		} else {
			IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), amount);
			IERC721Mintable(loansContract).mint(msg.sender, pawnTicketID);
		}

		pawnTickets[pawnTicketID] = PawnTicket({
			loanAsset: ticket.loanAsset,
			collateralID: ticket.collateralID,
			collateralAddress: ticket.collateralAddress,
			perBlockInterestRate: interest,
			accumulatedInterest: 0,
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
		IERC20(ticket.loanAsset).transferFrom(address(this), msg.sender, amount);
	}

	function repayAndCloseLoan(uint256 pawnTicketID) ticketExists(pawnTicketID) external {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		uint256 interest = interestOwed(pawnTicketID);
		IERC20(ticket.loanAsset).transferFrom(msg.sender, address(this), interest + ticket.loanAmountDrawn);
		address loanOwner = IERC721(loansContract).ownerOf(pawnTicketID);
		uint256 loanPaymentBalance = _loanPaymentBalances[pawnTicketID][loanOwner];
		_loanPaymentBalances[pawnTicketID][loanOwner] = loanPaymentBalance + interest + ticket.loanAmount;
		ticket.closed = true;
		IERC721(ticket.collateralAddress).transferFrom(address(this), ownerOf(pawnTicketID), pawnTicketID);
	}

	function seizeCollateral(uint256 pawnTicketID) ticketExists(pawnTicketID) external {
		PawnTicket storage ticket = pawnTickets[pawnTicketID];
		require(!ticket.closed, "NFTPawnShop: ticket closed");
		require(block.number > ticket.blockDuration + ticket.lastAccumulatedInterestBlock, "NFTPawnShop: payment is not late");
		IERC721(ticket.collateralAddress).transferFrom(address(this), IERC721(loansContract).ownerOf(pawnTicketID), pawnTicketID);
		ticket.closed = true;

	}

	function withdrawLoanPayment(uint256 pawnTicketID, uint256 amount) ticketExists(pawnTicketID) external {
		_loanPaymentBalances[pawnTicketID][msg.sender] = _loanPaymentBalances[pawnTicketID][msg.sender].sub(amount, "NFTPawnShop: Insufficient balance");
		IERC20(pawnTickets[pawnTicketID].loanAsset).transferFrom(address(this), msg.sender, amount);
	}

	// === manger state changing
}

// create loan info, mint lockedAsset token
// someone takes on the loan, gets the loan token
// 