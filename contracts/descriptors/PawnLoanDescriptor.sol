import './PawnShopNFTDescriptor.sol';

contract PawnLoanDescriptor is PawnShopNFTDescriptor {
    constructor(ITicketTypeSpecificSVGHelper _svgHelper) PawnShopNFTDescriptor("loan", _svgHelper) {
    }

    function generateDescription(string memory pawnTicketId) internal virtual override pure returns (string memory) {
        return string(
                abi.encodePacked(
                    'This Pawn Shop Loan NFT was created when Pawn Shop Ticket #', 
                    pawnTicketId,
                    ' was underwritten. If the loan is paid back on time, the holder of this NFT is entitled to the loaned funds plus interest. If it is not paid back on time, the holder of this ticket is entitled to seize the NFT collateral.\\n'
                )
            );
    }

}