pragma solidity 0.8.6;

interface IPawnShop {
    // @notice Emitted when pawn ticket is created
    // @param id The id of the new ticket, matches token id of pawn ticket nft
    // @param minter msg.sender
    // @param maxInterestRate max per second interest rate, scaled by SCALAR
    // @param minLoanAmount mimimum loan amount
    // @param minDurationSeconds minimum loan duration in seconds
    event MintTicket(uint256 indexed id, address indexed minter, uint256 maxInterestRate, uint256 minLoanAmount, uint256 minDurationSeconds);

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
    event Repay(uint256 indexed id, address indexed repayer, address indexed loanOwner, uint256 interestEarned, uint256 loanAmount);
    event SeizeCollateral(uint256 indexed id);
}