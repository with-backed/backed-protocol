pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import './interfaces/INFTLoanFacilitator.sol';
import './interfaces/IMintable.sol';
import './interfaces/ILendTicket.sol';
import './interfaces/IERC20Metadata.sol';


struct Loan {
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
    uint256 collateralTokenId;
    address collateralContractAddress;
    address loanAssetContractAddress;
    
}

contract NFTLoanFacilitator is Ownable, INFTLoanFacilitator {
    using SafeERC20 for IERC20;

    // 10^INTEREST_RATE_DECIMALS = 1 = 100%
    uint8 public constant override INTEREST_RATE_DECIMALS = 10;
    uint256 public constant override SCALAR = 10 ** INTEREST_RATE_DECIMALS;

    // 1%
    uint256 public originationFeeRate = 10 ** (INTEREST_RATE_DECIMALS - 2);
    uint256 private _nonce;

    address public lendTicketContract;
    address public borrowTicketContract;

    mapping(uint256 => Loan) public override loanInfo;

    // ==== modifiers
    modifier loanExists(uint256 loanId) { 
        require(loanId <= _nonce, "NFTLoanFacilitator: loan does not exist");
        _; 
    }

    // ==== view ====
    function totalOwed(uint256 loanId) loanExists(loanId) override view external returns (uint256) {
        Loan storage loan = loanInfo[loanId];
        if(loan.closed || loan.lastAccumulatedTimestamp == 0){
            return 0;
        }

        return loanInfo[loanId].loanAmount + _interestOwed(loan);
    }

    function interestOwed(uint256 loanId) loanExists(loanId) override view public returns (uint256) {
        Loan storage loan = loanInfo[loanId];
        return _interestOwed(loan);
    }

    function _interestOwed(Loan storage loan) private view returns (uint256) {
        if(loan.closed || loan.lastAccumulatedTimestamp == 0){
            return 0;
        }
        
        return loan.loanAmount
            * (block.timestamp - loan.lastAccumulatedTimestamp)
            * loan.perSecondInterestRate
            / SCALAR
            + loan.accumulatedInterest;
    }

    function loanEndSeconds(uint256 loanId) loanExists(loanId) override view external returns (uint256) {
        Loan storage loan = loanInfo[loanId];
        return loan.durationSeconds + loan.lastAccumulatedTimestamp;
    }

    constructor(address _manager) {
        transferOwnership(_manager);
    }

    // ==== state changing ====
    function createLoan(
            uint256 collateralTokenId,
            address collateralContractAddress,
            uint256 maxPerSecondInterest,
            uint256 minLoanAmount,
            address loanAssetContractAddress,
            uint256 minDurationSeconds,
            address mintBorrowTicketTo
        )
        override
        external
        returns(uint256 id) 
    {
        require(collateralContractAddress != lendTicketContract 
        && collateralContractAddress != borrowTicketContract, 
        'NFTLoanFacilitator: cannot use tickets as collateral');
        
        IERC721(collateralContractAddress).transferFrom(msg.sender, address(this), collateralTokenId);

        id = ++_nonce;
        Loan storage loan = loanInfo[id];
        loan.loanAssetContractAddress = loanAssetContractAddress;
        loan.loanAmount = minLoanAmount;
        loan.collateralTokenId = collateralTokenId;
        loan.collateralContractAddress = collateralContractAddress;
        loan.perSecondInterestRate = maxPerSecondInterest;
        loan.durationSeconds = minDurationSeconds;
        
        IMintable(borrowTicketContract).mint(mintBorrowTicketTo, id);
        emit CreateLoan(
            id,
            msg.sender,
            collateralTokenId,
            collateralContractAddress,
            maxPerSecondInterest,
            loanAssetContractAddress,
            minLoanAmount,
            minDurationSeconds
            );
    }

    function closeLoan(uint256 loanId, address sendCollateralTo) override external {
        require(IERC721(borrowTicketContract).ownerOf(loanId) == msg.sender, "NFTLoanFacilitator: borrower only");

        Loan storage loan = loanInfo[loanId];
        require(!loan.closed, "NFTLoanFacilitator: loan closed");
        require(loan.lastAccumulatedTimestamp == 0, "NFTLoanFacilitator: underwritten, use repayAndCloseLoan");
        
        loan.closed = true;
        IERC721(loan.collateralContractAddress).transferFrom(address(this), sendCollateralTo, loan.collateralTokenId);
        emit Close(loanId);
    }

    function underwriteLoan(
            uint256 loanId,
            uint256 interestRate,
            uint256 amount,
            uint256 durationSeconds,
            address sendLendTicketTo
        ) 
        override
        loanExists(loanId)
        external 
    {
        Loan storage loan = loanInfo[loanId];
        require(!loan.closed, "NFTLoanFacilitator: loan closed");
        require(loan.perSecondInterestRate >= interestRate 
        && loan.durationSeconds <= durationSeconds && loan.loanAmount <= amount, 
        "NFTLoanFacilitator: Proposed terms do not qualify" );

        if(loan.lastAccumulatedTimestamp == 0){
            loan.perSecondInterestRate = interestRate;
            loan.lastAccumulatedTimestamp = block.timestamp;
            loan.durationSeconds = durationSeconds;
            loan.loanAmount = amount;

            IERC20(loan.loanAssetContractAddress).safeTransferFrom(msg.sender, address(this), amount);
            uint256 facilitatorTake = amount * originationFeeRate / SCALAR;
            IERC20(loan.loanAssetContractAddress).safeTransfer(
                IERC721(borrowTicketContract).ownerOf(loanId),
                amount - facilitatorTake
                );
            IMintable(lendTicketContract).mint(sendLendTicketTo, loanId);
        } else {
            uint256 amountIncrease = amount - loan.loanAmount;
            require((loan.loanAmount * 10 / 100) <= amountIncrease
            || loan.durationSeconds + (loan.durationSeconds * 10 / 100) <= durationSeconds 
            || loan.perSecondInterestRate - (loan.perSecondInterestRate * 10 / 100) >= interestRate, 
            "NFTLoanFacilitator: proposed terms must be better than existing terms");

            uint256 accumulatedInterest = _interestOwed(loan);
            uint256 previousLoanAmount = loan.loanAmount;

            loan.perSecondInterestRate = interestRate;
            loan.lastAccumulatedTimestamp = block.timestamp;
            loan.durationSeconds = durationSeconds;
            loan.loanAmount = amount;

            IERC20(loan.loanAssetContractAddress).safeTransferFrom(
                msg.sender,
                address(this),
                amount + accumulatedInterest
                );
            address currentLoanOwner = IERC721(lendTicketContract).ownerOf(loanId);
            IERC20(loan.loanAssetContractAddress).safeTransfer(currentLoanOwner, accumulatedInterest + previousLoanAmount);
            ILendTicket(lendTicketContract).loanFacilitatorTransfer(currentLoanOwner, sendLendTicketTo, loanId);
            if(amountIncrease > 0){
                uint256 facilitatorTake = (amountIncrease * originationFeeRate / SCALAR);
                IERC20(loan.loanAssetContractAddress).safeTransfer(
                    IERC721(borrowTicketContract).ownerOf(loanId),
                    amount - previousLoanAmount - facilitatorTake
                    );
            }

            loan.accumulatedInterest = accumulatedInterest;
            emit BuyoutUnderwriter(loanId, msg.sender, currentLoanOwner, accumulatedInterest, previousLoanAmount);
        }
        emit UnderwriteLoan(loanId, msg.sender, interestRate, amount, durationSeconds);
    }

    function repayAndCloseLoan(uint256 loanId) loanExists(loanId) override external {
        Loan storage loan = loanInfo[loanId];
        require(!loan.closed, "NFTLoanFacilitator: loan closed");

        uint256 interest = _interestOwed(loan);
        address loanOwner = IERC721(lendTicketContract).ownerOf(loanId);
        loan.closed = true;
        IERC20(loan.loanAssetContractAddress).safeTransferFrom(msg.sender, loanOwner, interest + loan.loanAmount);
        IERC721(loan.collateralContractAddress).transferFrom(
            address(this),
            IERC721(borrowTicketContract).ownerOf(loanId),
            loan.collateralTokenId
            );
        emit Repay(loanId, msg.sender, loanOwner, interest, loan.loanAmount);
        emit Close(loanId);
    }

    function seizeCollateral(uint256 loanId, address sendCollateralTo) override external {
        require(IERC721(lendTicketContract).ownerOf(loanId) == msg.sender, "NFTLoanFacilitator: underwriter only");

        Loan storage loan = loanInfo[loanId];
        require(!loan.closed, "NFTLoanFacilitator: loan closed");
        require(block.timestamp > loan.durationSeconds + loan.lastAccumulatedTimestamp,
        "NFTLoanFacilitator: payment is not late");

        loan.closed = true;
        IERC721(loan.collateralContractAddress).transferFrom(address(this), sendCollateralTo, loan.collateralTokenId);
        emit SeizeCollateral(loanId);
        emit Close(loanId);
    }

    // === manger state changing

    function setLendTicketContract(address _contract) onlyOwner() external {
        require(lendTicketContract == address(0), 'NFTLoanFacilitator: already set');

        lendTicketContract = _contract;
    }

    function setBorrowTicketContract(address _contract) onlyOwner() external {
        require(borrowTicketContract == address(0), 'NFTLoanFacilitator: already set');

        borrowTicketContract = _contract;
    }

    function withdrawOriginationFees(address asset, uint256 amount, address to) onlyOwner() external {
        IERC20(asset).safeTransfer(to, amount);
    }

    function updateOriginationFeeRate(uint256 _originationFeeRate) onlyOwner() external {
        require(_originationFeeRate <= 5 * (10 ** (INTEREST_RATE_DECIMALS - 2)), "NFTLoanFacilitator: max fee 5%");
        
        originationFeeRate = _originationFeeRate;
    }
}
