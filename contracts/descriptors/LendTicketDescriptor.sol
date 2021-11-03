pragma solidity 0.8.6;

import './NFTLoansTicketDescriptor.sol';

contract LendTicketDescriptor is NFTLoansTicketDescriptor {
    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(ITicketTypeSpecificSVGHelper _svgHelper) NFTLoansTicketDescriptor("Lend", _svgHelper) {
    }

    /**
     * @notice returns string with lend ticket description details
     * @dev Called by generateDescriptor when populating the description part of the token metadata. 
     */
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