pragma solidity 0.8.10;

import './interfaces/ILendTicket.sol';
import './NFTLoanTicket.sol';
import './descriptors/NFTLoansTicketDescriptor.sol';

contract LendTicket is NFTLoanTicket, ILendTicket {

    /// See NFTLoanTicket
    constructor(
        NFTLoanFacilitator _nftLoanFacilitator,
        NFTLoansTicketDescriptor _descriptor
    ) 
        NFTLoanTicket("Lend Ticket", "LNDT", _nftLoanFacilitator, _descriptor) 
    {}

    /// See {ILendTicket-loanFacilitatorTransfer}
    function loanFacilitatorTransfer(address from, address to, uint256 loanId) external override loanFacilitatorOnly {
<<<<<<< HEAD
        _safeTransfer(from, to, loanId, "");
=======
        _transfer(from, to, loanId);
>>>>>>> 966e1c3 (more style fixes)
    }
}