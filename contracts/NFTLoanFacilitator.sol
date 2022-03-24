pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeTransferLib, ERC20} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import './interfaces/INFTLoanFacilitator.sol';
import './interfaces/IERC721Mintable.sol';
import './interfaces/ILendTicket.sol';

contract NFTLoanFacilitator is Ownable, INFTLoanFacilitator {
    using SafeTransferLib for ERC20;

    // ==== constants ====

    /** 
     * See {INFTLoanFacilitator-INTEREST_RATE_DECIMALS}.     
     * @dev lowest non-zero APR possible = (1/10^10)*(60*60*24*365) = 0.003 = 0.3%
     */
    uint8 public constant override INTEREST_RATE_DECIMALS = 10;

    /// See {INFTLoanFacilitator-SCALAR}.
    uint256 public constant override SCALAR = 10 ** INTEREST_RATE_DECIMALS;

    
    // ==== state variables ====

    /// See {INFTLoanFacilitator-originationFeeRate}.
    uint256 public override originationFeeRate = 10 ** (INTEREST_RATE_DECIMALS - 2);

    /// @dev tracks loan count
    uint256 private _nonce = 1;

    /// See {INFTLoanFacilitator-lendTicketContract}.
    address public override lendTicketContract;

    /// See {INFTLoanFacilitator-borrowTicketContract}.
    address public override borrowTicketContract;

    /// See {INFTLoanFacilitator-requiredImprovementPercentage}.
    uint256 public override requiredImprovementPercentage = 10;

    mapping(uint256 => Loan) public _loanInfo;

    
    // ==== modifiers ====

    modifier notClosed(uint256 loanId) { 
        require(!_loanInfo[loanId].closed, "NFTLoanFacilitator: loan closed");
        _; 
    }

    constructor(address _manager) {
        transferOwnership(_manager);
    }

    
    // ==== state changing external functions ====

    /// See {INFTLoanFacilitator-createLoan}.
    function createLoan(
            uint256 collateralTokenId,
            address collateralContractAddress,
            uint16 maxPerSecondInterest,
            uint256 minLoanAmount,
            address loanAssetContractAddress,
            uint32 minDurationSeconds,
            address mintBorrowTicketTo
        )
        external
        override
        returns (uint256 id) 
    {
        require(minDurationSeconds != 0, 'NFTLoanFacilitator: 0 duration');
        require(minLoanAmount != 0, 'NFTLoanFacilitator: 0 loan amount');
        require(loanAssetContractAddress != address(0), 'NFTLoanFacilitator: invalid loanAssetContractAddress');
        require(collateralContractAddress != lendTicketContract,
        'NFTLoanFacilitator: cannot use tickets as collateral');
        require(collateralContractAddress != borrowTicketContract, 
        'NFTLoanFacilitator: cannot use tickets as collateral');
        
        IERC721(collateralContractAddress).transferFrom(msg.sender, address(this), collateralTokenId);

        id = _nonce++;
        Loan storage loan = _loanInfo[id];
        loan.loanAssetContractAddress = loanAssetContractAddress;
        loan.loanAmount = minLoanAmount;
        loan.collateralTokenId = collateralTokenId;
        loan.collateralContractAddress = collateralContractAddress;
        loan.perSecondInterestRate = maxPerSecondInterest;
        loan.durationSeconds = minDurationSeconds;
        
        IERC721Mintable(borrowTicketContract).mint(mintBorrowTicketTo, id);
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

    /// See {INFTLoanFacilitator-closeLoan}.
    function closeLoan(uint256 loanId, address sendCollateralTo) external override notClosed(loanId) {
        require(IERC721(borrowTicketContract).ownerOf(loanId) == msg.sender, "NFTLoanFacilitator: borrower only");

        Loan storage loan = _loanInfo[loanId];
        require(loan.lastAccumulatedTimestamp == 0, "NFTLoanFacilitator: has lender, use repayAndCloseLoan");
        
        loan.closed = true;
        IERC721(loan.collateralContractAddress).transferFrom(address(this), sendCollateralTo, loan.collateralTokenId);
        emit Close(loanId);
    }

    /// See {INFTLoanFacilitator-lend}.
    function lend(
            uint256 loanId,
            uint16 interestRate,
            uint256 amount,
            uint32 durationSeconds,
            address sendLendTicketTo
        )
        external
        override
        notClosed(loanId)
    {
        Loan storage loan = _loanInfo[loanId];
        address loanAssetContractAddress = loan.loanAssetContractAddress;

        require(loan.perSecondInterestRate >= interestRate, 'NFTLoanFacilitator: rate too high');
        require(loan.durationSeconds <= durationSeconds, 'NFTLoanFacilitator: duration too low');
        require(loan.loanAmount <= amount, 'NFTLoanFacilitator: amount too low');

        if (loan.lastAccumulatedTimestamp == 0) {
            loan.perSecondInterestRate = interestRate;
            loan.lastAccumulatedTimestamp = uint40(block.timestamp);
            loan.durationSeconds = durationSeconds;
            loan.loanAmount = amount;

            ERC20(loanAssetContractAddress).safeTransferFrom(msg.sender, address(this), amount);
            uint256 facilitatorTake = amount * originationFeeRate / SCALAR;
            ERC20(loanAssetContractAddress).safeTransfer(
                IERC721(borrowTicketContract).ownerOf(loanId),
                amount - facilitatorTake
                );
            IERC721Mintable(lendTicketContract).mint(sendLendTicketTo, loanId);
        } else {
            uint256 amountIncrease = amount - loan.loanAmount;
            uint256 previousLoanAmount = loan.loanAmount;

            {
                uint16 previousInterestRate = loan.perSecondInterestRate;
                uint32 previousDurationSeconds = loan.durationSeconds;

                require((previousLoanAmount * requiredImprovementPercentage / 100) <= amountIncrease
                || previousDurationSeconds + (previousDurationSeconds * requiredImprovementPercentage / 100) <= durationSeconds 
                || (previousInterestRate != 0 && previousInterestRate - (previousInterestRate * requiredImprovementPercentage / 100) >= interestRate), 
                "NFTLoanFacilitator: proposed terms must be better than existing terms");
            }

            uint256 accumulatedInterest = _interestOwed(
                previousLoanAmount,
                loan.lastAccumulatedTimestamp,
                loan.perSecondInterestRate,
                loan.accumulatedInterest
            );

            loan.perSecondInterestRate = interestRate;
            loan.lastAccumulatedTimestamp = uint40(block.timestamp);
            loan.durationSeconds = durationSeconds;
            loan.loanAmount = amount;
            loan.accumulatedInterest = accumulatedInterest;

            address currentLoanOwner = IERC721(lendTicketContract).ownerOf(loanId);
            if (amountIncrease > 0) {
                ERC20(loanAssetContractAddress).safeTransferFrom(
                    msg.sender,
                    address(this),
                    amount + accumulatedInterest
                );
                ERC20(loanAssetContractAddress).safeTransfer(
                    currentLoanOwner,
                    accumulatedInterest + previousLoanAmount
                );
                uint256 facilitatorTake = (amountIncrease * originationFeeRate / SCALAR);
                ERC20(loanAssetContractAddress).safeTransfer(
                    IERC721(borrowTicketContract).ownerOf(loanId),
                    amountIncrease - facilitatorTake
                );
            } else {
                ERC20(loanAssetContractAddress).safeTransferFrom(
                    msg.sender,
                    currentLoanOwner,
                    accumulatedInterest + previousLoanAmount
                );
            }
            ILendTicket(lendTicketContract).loanFacilitatorTransfer(currentLoanOwner, sendLendTicketTo, loanId);
            
            emit BuyoutLender(loanId, msg.sender, currentLoanOwner, accumulatedInterest, previousLoanAmount);
        }

        emit Lend(loanId, msg.sender, interestRate, amount, durationSeconds);
    }

    /// See {INFTLoanFacilitator-repayAndCloseLoan}.
    function repayAndCloseLoan(uint256 loanId) external override notClosed(loanId) {
        Loan storage loan = _loanInfo[loanId];

        uint256 interest = _interestOwed(
            loan.loanAmount,
            loan.lastAccumulatedTimestamp,
            loan.perSecondInterestRate,
            loan.accumulatedInterest
        );
        address lender = IERC721(lendTicketContract).ownerOf(loanId);
        loan.closed = true;
        ERC20(loan.loanAssetContractAddress).safeTransferFrom(msg.sender, lender, interest + loan.loanAmount);
        IERC721(loan.collateralContractAddress).transferFrom(
            address(this),
            IERC721(borrowTicketContract).ownerOf(loanId),
            loan.collateralTokenId
        );

        emit Repay(loanId, msg.sender, lender, interest, loan.loanAmount);
        emit Close(loanId);
    }

    /// See {INFTLoanFacilitator-seizeCollateral}.
    function seizeCollateral(uint256 loanId, address sendCollateralTo) external override notClosed(loanId) {
        require(IERC721(lendTicketContract).ownerOf(loanId) == msg.sender, "NFTLoanFacilitator: loan ticket holder only");

        Loan storage loan = _loanInfo[loanId];
        require(block.timestamp > loan.durationSeconds + loan.lastAccumulatedTimestamp,
        "NFTLoanFacilitator: payment is not late");

        loan.closed = true;
        IERC721(loan.collateralContractAddress).transferFrom(address(this), sendCollateralTo, loan.collateralTokenId);
        emit SeizeCollateral(loanId);
        emit Close(loanId);
    }

    
    // === owner state changing ===

    /**
     * @notice Sets lendTicketContract to _contract
     * @dev cannot be set if lendTicketContract is already set
     */
    function setLendTicketContract(address _contract) external onlyOwner {
        require(lendTicketContract == address(0), 'NFTLoanFacilitator: already set');

        lendTicketContract = _contract;
    }

    /**
     * @notice Sets borrowTicketContract to _contract
     * @dev cannot be set if borrowTicketContract is already set
     */
    function setBorrowTicketContract(address _contract) external onlyOwner {
        require(borrowTicketContract == address(0), 'NFTLoanFacilitator: already set');

        borrowTicketContract = _contract;
    }

    /// @notice Transfers `amount` of loan origination fees for `asset` to `to`
    function withdrawOriginationFees(address asset, uint256 amount, address to) external onlyOwner {
        ERC20(asset).safeTransfer(to, amount);

        emit WithdrawOriginationFees(asset, amount, to);
    }

    /**
     * @notice Updates originationFeeRate the faciliator keeps of each loan amount
     * @dev Cannot be set higher than 5%
     */
    function updateOriginationFeeRate(uint32 _originationFeeRate) external onlyOwner {
        require(_originationFeeRate <= 5 * (10 ** (INTEREST_RATE_DECIMALS - 2)), "NFTLoanFacilitator: max fee 5%");
        
        originationFeeRate = _originationFeeRate;

        emit UpdateOriginationFeeRate(_originationFeeRate);
    }

    /**
     * @notice updates the percent improvement required of at least one loan term when buying out lender 
     * a loan that already has a lender. E.g. setting this value to 10 means duration or amount
     * must be 10% higher or interest rate must be 10% lower. 
     */
    function updateRequiredImprovementPercentage(uint256 _improvementPercentage) external onlyOwner {
        requiredImprovementPercentage = _improvementPercentage;

        emit UpdateRequiredImprovementPercent(_improvementPercentage);
    }

    
    // ==== external view ====

    /// See {INFTLoanFacilitator-loanInfo}.
    function loanInfo(uint256 loanId)
        external 
        view 
        override
        returns (
            bool closed,
            uint16 perSecondInterestRate,
            uint32 durationSeconds,
            uint40 lastAccumulatedTimestamp,
            address collateralContractAddress,
            address loanAssetContractAddress,
            uint256 accumulatedInterest,
            uint256 loanAmount,
            uint256 collateralTokenId
        ) 
    {
        Loan memory loan = _loanInfo[loanId];
        return (
            loan.closed,
            loan.perSecondInterestRate,
            loan.durationSeconds,
            loan.lastAccumulatedTimestamp,
            loan.collateralContractAddress,
            loan.loanAssetContractAddress,
            loan.accumulatedInterest,
            loan.loanAmount,
            loan.collateralTokenId
        );
    }

    /// See {INFTLoanFacilitator-totalOwed}.
    function totalOwed(uint256 loanId) external view override returns (uint256) {
        Loan storage loan = _loanInfo[loanId];
        if (loan.closed || loan.lastAccumulatedTimestamp == 0) return 0;

        return _loanInfo[loanId].loanAmount + _interestOwed(
            loan.loanAmount,
            loan.lastAccumulatedTimestamp,
            loan.perSecondInterestRate,
            loan.accumulatedInterest
        );
    }

    /// See {INFTLoanFacilitator-interestOwed}.
    function interestOwed(uint256 loanId) external view override returns (uint256) {
        Loan storage loan = _loanInfo[loanId];
        if(loan.closed || loan.lastAccumulatedTimestamp == 0) return 0;

        return _interestOwed(
            loan.loanAmount,
            loan.lastAccumulatedTimestamp,
            loan.perSecondInterestRate,
            loan.accumulatedInterest
        );
    }

    /// See {INFTLoanFacilitator-loanEndSeconds}.
    function loanEndSeconds(uint256 loanId) external view override returns (uint256) {
        Loan storage loan = _loanInfo[loanId];
        return loan.durationSeconds + loan.lastAccumulatedTimestamp;
    }

    
    // === private ===

    /// @dev Returns the interest owed, in loan asset units, for `loan`
    function _interestOwed(
        uint256 loanAmount,
        uint40 lastAccumulatedTimestamp,
        uint16 perSecondInterestRate,
        uint256 accumulatedInterest
    ) 
        internal 
        view 
        returns (uint256) 
    {
        return loanAmount
            * (block.timestamp - lastAccumulatedTimestamp)
            * perSecondInterestRate
            / SCALAR
            + accumulatedInterest;
    }
}
