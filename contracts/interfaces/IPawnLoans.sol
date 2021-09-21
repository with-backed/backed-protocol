pragma solidity 0.8.6;

interface IPawnLoans {
    function pawnShopTransferLoan(address from, address to, uint256 loanId) external;
}