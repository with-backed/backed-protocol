pragma solidity 0.8.10;

interface INFTLoanFacilitator {
    /// @notice See loanInfo
    struct Loan {
        bool closed;
        uint16 perSecondInterestRate;
        uint32 durationSeconds;
        uint40 lastAccumulatedTimestamp;
        address collateralContractAddress;
        address loanAssetContractAddress;
        uint256 accumulatedInterest;
        uint256 loanAmount;
        uint256 collateralTokenId;
    }

    /**
     * @notice The magnitude of SCALAR
     * @dev 10^INTEREST_RATE_DECIMALS = 1 = 100%
     */
    function INTEREST_RATE_DECIMALS() external returns (uint8);

    /**
     * @notice The SCALAR for all percentages in the loan facilitator contract
     * @dev Any interest rate passed to a function should already been multiplied by SCALAR
     */
    function SCALAR() external returns (uint256);

    /**
     * @notice The percent of the loan amount that the facilitator will take as a fee, scaled by SCALAR
     * @dev Starts set to 1%. Can only be set to 0 - 5%. 
     */
    function originationFeeRate() external returns (uint256);

    /**
     * @notice The lend ticket contract associated with this loan faciliator
     * @dev Once set, cannot be modified
     */
    function lendTicketContract() external returns (address);

    /**
     * @notice The borrow ticket contract associated with this loan faciliator
     * @dev Once set, cannot be modified
     */
    function borrowTicketContract() external returns (address);

    /**
     * @notice The percent improvement required of at least one loan term when buying out current lender 
     * a loan that already has a lender. E.g. setting this value to 10 means duration or amount
     * must be 10% higher or interest rate must be 10% lower.
     * @dev Starts at 10. Only owner can set.
     */
    function requiredImprovementPercentage() external returns (uint256);
    
    /**
     * @notice Emitted when the loan is created
     * @param id The id of the new loan, matches the token id of the borrow ticket minted in the same transaction
     * @param minter msg.sender
     * @param collateralTokenId The token id of the collateral NFT
     * @param collateralContract The contract address of the collateral NFT
     * @param maxInterestRate The max per second interest rate, scaled by SCALAR
     * @param loanAssetContract The contract address of the loan asset
     * @param minLoanAmount mimimum loan amount
     * @param minDurationSeconds minimum loan duration in seconds
    */
    event CreateLoan(
        uint256 indexed id,
        address indexed minter,
        uint256 collateralTokenId,
        address collateralContract,
        uint256 maxInterestRate,
        address loanAssetContract,
        uint256 minLoanAmount,
        uint256 minDurationSeconds
        );

    /** 
     * @notice Emitted when ticket is closed
     * @param id The id of the ticket which has been closed
     */
    event Close(uint256 indexed id);

    /** 
     * @notice Emitted when the loan is underwritten or re-underwritten
     * @param id The id of the ticket which is being underwritten
     * @param lender msg.sender
     * @param interestRate The per second interest rate, scaled by SCALAR, for the loan
     * @param loanAmount The loan amount
     * @param durationSeconds The loan duration in seconds 
     */
    event Lend(
        uint256 indexed id,
        address indexed lender,
        uint256 interestRate,
        uint256 loanAmount,
        uint256 durationSeconds
        );

    /**
     * @notice Emitted when a loan is being re-underwritten, the current loan ticket holder is being bought out
     * @param lender msg.sender
     * @param replacedLoanOwner The current loan ticket holder
     * @param interestEarned The amount of interest the loan has accrued from first lender to this buyout
     * @param replacedAmount The loan amount prior to buyout
     */    
    event BuyoutLender(
        uint256 indexed id,
        address indexed lender,
        address indexed replacedLoanOwner,
        uint256 interestEarned,
        uint256 replacedAmount
        );
    
    /**
     * @notice Emitted when loan is repaid
     * @param id The loan id
     * @param repayer msg.sender
     * @param loanOwner The current holder of the lend ticket for this loan, token id matching the loan id
     * @param interestEarned The total interest accumulated on the loan
     * @param loanAmount The loan amount
     */
    event Repay(
        uint256 indexed id,
        address indexed repayer,
        address indexed loanOwner,
        uint256 interestEarned,
        uint256 loanAmount
        );

    /**
     * @notice Emitted when loan NFT collateral is seized 
     * @param id The ticket id
     */
    event SeizeCollateral(uint256 indexed id);

     /**
      * @notice Emitted when origination fees are withdrawn
      * @dev only owner can call
      * @param asset the ERC20 asset withdrawn
      * @param amount the amount withdrawn
      * @param to the address the withdrawn amount was sent to
      */
     event WithdrawOriginationFees(address asset, uint256 amount, address to);

      /**
      * @notice Emitted when originationFeeRate is updated
      * @dev only owner can call, value is scaled by SCALAR, 100% = SCALAR
      * @param feeRate the new origination fee rate
      */
     event UpdateOriginationFeeRate(uint32 feeRate);

     /**
      * @notice Emitted when requiredImprovementPercent is updated
      * @dev only owner can call, 1 = 1%
      * @param improvementPercent the new required improvementPercent
      */
     event UpdateRequiredImprovementPercent(uint256 improvementPercent);

    /**
     * @notice returns the info for this loan
     * @param loanId The id of the loan
     * @return closed Whether or not the ticket is closed
     * @return perSecondInterestRate The per second interest rate, scaled by SCALAR
     * @return accumulatedInterest The amount of interest accumulated on the loan prior to the current lender
     * @return lastAccumulatedTimestamp The timestamp (in seconds) when interest was last accumulated, 
     * i.e. the timestamp of the most recent underwriting
     * @return collateralContractAddress The contract address of the NFT collateral 
     * @return loanAssetContractAddress The contract address of the loan asset.
     * @return durationSeconds The loan duration in seconds
     * @return loanAmount The loan amount
     * @return collateralTokenId The token ID of the NFT collateral
     */
    function loanInfo(uint256 loanId)
    external view 
    returns (
        bool closed,
        uint16 perSecondInterestRate,
        uint32 accumulatedInterest,
        uint40 lastAccumulatedTimestamp,
        address collateralContractAddress,
        address loanAssetContractAddress,
        uint256 durationSeconds,
        uint256 loanAmount,
        uint256 collateralTokenId
        );

    /**
     * @notice (1) transfers the collateral NFT to the loan facilitator contract 
     * (2) creates the loan, populating loanInfo in the facilitator contract,
     * and (3) mints a Borrow Ticket to mintBorrowTicketTo
     * @param collateralTokenId The token id of the collateral NFT 
     * @param collateralContractAddress The contract address of the collateral NFT
     * @param maxPerSecondInterest The maximum per second interest rate for this loan, scaled by SCALAR
     * @param minLoanAmount The minimum acceptable loan amount for this loan
     * @param loanAssetContractAddress The address of the loan asset
     * @param minDurationSeconds The minimum duration for this loan
     * @param mintBorrowTicketTo An address to mint the Borrow Ticket corresponding to this loan to
     * @return id of the created loan
     */
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
        returns (uint256 id);

    /**
     * @notice Closes the loan, sends the NFT collateral to sendCollateralTo
     * @dev Can only be called by the holder of the Borrow Ticket with tokenId
     * matching the loanId. Can only be called if loan has not be underwritten,
     * i.e. lastAccumulatedInterestTimestamp = 0
     * @param loanId The loan id
     * @param sendCollateralTo The address to send the collateral NFT to
     */
    function closeLoan(uint256 loanId, address sendCollateralTo) external;

    /**
     * @notice Lends, meeting or beating the proposed loan terms, 
     * transferring `amount` of the loan asset 
     * to the facilitator contract. If the loan has not yet been underwritten, 
     * a Lend Ticket is minted to `sendLendTicketTo`. If the loan has already been 
     * underwritten, then this is a buyout, and the Lend Ticket will be transferred
     * from the current holder to `sendLendTicketTo`. Also in the case of a buyout, interestOwed()
     * is transferred from the caller to the facilitator contract, in addition to `amount`, and
     * totalOwed() is paid to the current Lend Ticket holder.
     * @dev Loan terms must meet or beat loan terms. If a buyout, at least one loan term
     * must be improved by at least 10%. E.g. 10% longer duration, 10% lower interest, 
     * 10% higher amount
     * @param loanId The loan id
     * @param interestRate The per second interest rate, scaled by SCALAR
     * @param amount The loan amount
     * @param durationSeconds The loan duration in seconds
     * @param sendLendTicketTo The address to send the Lend Ticket to
     */
    function lend(
            uint256 loanId,
            uint16 interestRate,
            uint256 amount,
            uint32 durationSeconds,
            address sendLendTicketTo
        ) 
        external;

    /**
     * @notice repays and closes the loan, transferring totalOwed() to the current Lend Ticket holder
     * and transferring the collateral NFT to the Borrow Ticket holder.
     * @param loanId The loan id
     */
    function repayAndCloseLoan(uint256 loanId) external;

    /**
     * @notice Transfers the collateral NFT to `sendCollateralTo` and closes the loan.
     * @dev Can only be called by Lend Ticket holder. Can only be called 
     * if block.timestamp > loanEndSeconds()
     * @param loanId The loan id
     * @param sendCollateralTo The address to send the collateral NFT to
     */
    function seizeCollateral(uint256 loanId, address sendCollateralTo) external;

    /**
     * @notice returns the total amount owed for the loan, i.e. principal + interest
     * @param loanId The loan id
     */
    function totalOwed(uint256 loanId) view external returns (uint256);

    /**
     * @notice returns the interest owed on the loan, in loan asset units
     * @param loanId The loan id
     */
    function interestOwed(uint256 loanId) view external returns (uint256);

    /**
     * @notice returns the unix timestamp (seconds) of the loan end
     * @param loanId The loan id
     */
    function loanEndSeconds(uint256 loanId) view external returns (uint256);
}