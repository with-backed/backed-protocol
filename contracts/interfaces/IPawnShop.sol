pragma solidity 0.8.6;

interface IPawnShop {
    // @notice Emitted when pawn ticket is created
    // @param id The id of the new ticket, matches token id of pawn ticket nft
    // @param minter msg.sender
    // @param collateralTokenId The token id of the collateral NFT
    // @param collateralContract The contract address of the collateral NFT
    // @param maxInterestRate The max per second interest rate, scaled by SCALAR
    // @param loanAssetContract The contract address of the loan asset
    // @param minLoanAmount mimimum loan amount
    // @param minDurationSeconds minimum loan duration in seconds
    event MintTicket(uint256 indexed id, address indexed minter, uint256 collateralTokenId, address collateralContract, uint256 maxInterestRate, address loanAssetContract, uint256 minLoanAmount, uint256 minDurationSeconds);

    // @notice Emitted when ticket is closed
    // @param id The id of the ticket which has been closed
    event Close(uint256 indexed id);

    // @notice Emitted when the loan is underwritten or re-underwritten
    // @param id The id of the ticket which is being underwritten
    // @param underwriter msg.sender
    // @param interestRate The per second interest rate, scaled by SCALAR, for the loan
    // @param loanAmount The loan amount
    // @param durationSeconds The loan duration in seconds 
    event UnderwriteLoan(uint256 indexed id, address indexed underwriter, uint256 interestRate, uint256 loanAmount, uint256 durationSeconds);

    // @notice Emitted when a loan is being re-underwritten, the current underwriter is being bought out
    // @param underwriter msg.sender
    // @param replacedLoanOwner The previous underwriter
    // @param interestEarned The amount of interest the loan has accrued from first underwrite to this buyout
    // @param replacedAmount The loan amount prior to buyout
    event BuyoutUnderwriter(uint256 indexed id, address indexed underwriter, address indexed replacedLoanOwner, uint256 interestEarned, uint256 replacedAmount);
    
    // @notice Emitted when loan is repaid
    // @param id The pawn ticket id
    // @param repayer msg.sender
    // @param loanOwner The current holder of the pawn loan NFT (PWNL)
    // @param interestEarned The total interest accumulated on the loan
    // @param loanAmount The loan amount 
    event Repay(uint256 indexed id, address indexed repayer, address indexed loanOwner, uint256 interestEarned, uint256 loanAmount);

    // @notice Emitted when loan NFT collateral is seized 
    // @param id The ticket id
    event SeizeCollateral(uint256 indexed id);

    // @notice The magnitude of SCALAR
    // @dev 10^INTEREST_RATE_DECIMALS = 100%
    function INTEREST_RATE_DECIMALS() external returns (uint8);
    
    // @notice The SCALAR for all percentages in the pawn shop
    // @dev Any interest rate passed to a function should already been multiplied by SCALAR
    function SCALAR() external returns (uint256);

    // @notice returns the info for this pawn ticket
    // @param pawnTicketID The id of the pawn ticket
    // @return closed Whether or not the tickte is closed
    // @return perSecondInterestRate The person second interest rate, scaled by SCALAR
    // @return accumulatedInterest The amount of interest accumulated on the loan prior to the current underwriter
    // @return lastAccumulatedTimestamp The timestamp (in seconds) when interest was last accumulated, i.e. the timestamp of the most recent underwriting
    // @return durationSeconds The loan duration in seconds
    // @return loanAmount The loan amount
    // @return collateralID The token ID of the NFT collateal
    // @return collateralAddress The contract address of the NFT collateral 
    // @return loanAsset The contract address of the loan asset.
    function ticketInfo(uint256 pawnTicketID) external view returns (bool closed, uint256 perSecondInterestRate, uint256 accumulatedInterest, uint256 lastAccumulatedTimestamp, uint256 durationSeconds, uint256 loanAmount, uint256 collateralID, address collateralAddress, address loanAsset);
}