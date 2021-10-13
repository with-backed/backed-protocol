import './NFTLoansTicketDescriptor.sol';

contract BorrowTicketDescriptor is NFTLoansTicketDescriptor {
    constructor(ITicketTypeSpecificSVGHelper _svgHelper) NFTLoansTicketDescriptor("Borrow", _svgHelper) {
    }

    function generateDescription(string memory loanId) internal virtual override pure returns (string memory) {
        return string(
                abi.encodePacked(
                    'This Borrow Ticket NFT was created by the deposit an NFT into the NFT Loan Faciliator contract to serve as collateral for a loan. If the loan is underwritten, funds will be transferred to the borrow ticket holder. If the loan is repaid, the NFT collateral is transferred to the borrow ticket holder. If the loan is marked closed, the collateral has been withdrawn.\\n'
                )
            );
    }

}