// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import {ILendTicket} from './interfaces/ILendTicket.sol';
import {NFTLoanTicket} from './NFTLoanTicket.sol';
import {NFTLoanFacilitator} from './NFTLoanFacilitator.sol';
import {NFTLoansTicketDescriptor} from './descriptors/NFTLoansTicketDescriptor.sol';

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
        _transfer(from, to, loanId);
    }
}