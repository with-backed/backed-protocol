pragma solidity 0.8.6;

interface IPawnLoans {
    // @notice Transfers a pawn loan NFT
    // @dev can only be called by pawn shop
    // @param from The current holder of the pawn loan
    // @param to Address to send the pawn loan to
    // @param loanId The token id of the pawn loan NFT
    function pawnShopTransferLoan(address from, address to, uint256 loanId) external;
}