pragma solidity 0.8.6;

import './interfaces/ILendTicket.sol';
import './NFTLoanTicket.sol';
import './descriptors/NFTLoansTicketDescriptor.sol';

contract LendTicket is NFTLoanTicket, ILendTicket {

    constructor(
        NFTLoanFacilitator _nftLoanFacilitator,
        NFTLoansTicketDescriptor _descriptor
        ) 
        NFTLoanTicket("Lend Ticket", "LNDT", _nftLoanFacilitator, _descriptor) {}

    function loanFacilitatorTransfer(address from, address to, uint256 loanId) loanFacilitatorOnly() override external{
        _transfer(from, to, loanId);
    }
}