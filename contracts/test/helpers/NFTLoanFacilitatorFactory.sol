// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {NFTLoanFacilitator} from 'contracts/NFTLoanFacilitator.sol';
import {BorrowTicket} from 'contracts/BorrowTicket.sol';
import {LendTicket} from 'contracts/LendTicket.sol';
import {BorrowTicketDescriptor} from 'contracts/descriptors/BorrowTicketDescriptor.sol';
import {LendTicketDescriptor} from 'contracts/descriptors/LendTicketDescriptor.sol';
import {LendTicketSVGHelper} from 'contracts/descriptors/LendTicketSVGHelper.sol';
import {BorrowTicketSVGHelper} from 'contracts/descriptors/BorrowTicketSVGHelper.sol';
import {Vm} from './Vm.sol';
import {ERC1820Registry} from "../mocks/ERC1820Registry.sol";

contract NFTLoanFacilitatorFactory {
    Vm vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

    function newFacilitator(address manager)
        public 
        returns (
            BorrowTicket borrowTicket,
            LendTicket lendTicket,
            NFTLoanFacilitator facilitator
        )
    {
        ERC1820Registry registery = new ERC1820Registry();
        vm.etch(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24, address(registery).code);

        BorrowTicketSVGHelper bs = new BorrowTicketSVGHelper();
        BorrowTicketDescriptor bd = new BorrowTicketDescriptor(bs);

        LendTicketSVGHelper ls = new LendTicketSVGHelper();
        LendTicketDescriptor ld = new LendTicketDescriptor(ls);

        facilitator = new NFTLoanFacilitator(manager);
        borrowTicket = new BorrowTicket(facilitator, bd);
        lendTicket = new LendTicket(facilitator, ld);
        vm.startPrank(manager);
        facilitator.setBorrowTicketContract(address(borrowTicket));
        facilitator.setLendTicketContract(address(lendTicket));
        vm.stopPrank();
    }
}