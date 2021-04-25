pragma solidity ^0.8.2;

interface IPawnLoans {
    function loanPaidBack(uint256 loanId) view external returns (bool);
    function collateralSeized(uint256 loanId) view external returns (bool);
    function mintLoan(address to, uint256 pawnTicketId) external;
    function transferLoan(address from, address to, uint256 loanId) external;
    function setLoanPaidBack(uint256 loanId) external;
    function setCollateralSeized(uint256 loanId) external;
}