pragma solidity ^0.8.2;

interface IPawnLoans {
    function mintLoan(address to, uint256 pawnTicketId) external;
    function transferLoan(address from, address to, uint256 loanId) external;
}