// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import './NFTLoanTicket.sol';
import './descriptors/NFTLoansTicketDescriptor.sol';

contract BorrowTicket is NFTLoanTicket {

    /// See NFTLoanTicket
    constructor(
        NFTLoanFacilitator _nftLoanFacilitator,
        NFTLoansTicketDescriptor _descriptor
    ) 
        NFTLoanTicket("Borrow Ticket", "BRWT", _nftLoanFacilitator, _descriptor)
    {}
}