pragma solidity 0.8.6;

interface IPawnTickets {
    function mintTicket(address to, uint256 pawnTicketId) external;
}