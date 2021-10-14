pragma solidity 0.8.6;

import './NFTLoansTicketDescriptor.sol';

contract LendTicketDescriptor is NFTLoansTicketDescriptor {
    constructor(ITicketTypeSpecificSVGHelper _svgHelper) NFTLoansTicketDescriptor("Lend", _svgHelper) {
    }

    function generateDescription(string memory loanId) internal virtual override pure returns (string memory) {
        return string(
                abi.encodePacked(
                    'This Lend Ticket NFT was created when NFT Loan #', 
                    loanId,
                    ' was underwritten. On loan repayment, funds will be transferred to this ticket. If the loan is not paid back on time, the holder of this ticket is entitled to seize the NFT collateral.\\n'
                )
            );
    }

}