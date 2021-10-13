import './PawnShopNFTDescriptor.sol';

contract PawnTicketDescriptor is PawnShopNFTDescriptor {
    constructor(ITicketTypeSpecificSVGHelper _svgHelper) PawnShopNFTDescriptor("ticket", _svgHelper) {
    }

    function generateDescription(string memory pawnTicketId) internal virtual override pure returns (string memory) {
        return string(
                abi.encodePacked(
                    'This Pawn Shop Ticket NFT was created by the deposit an NFT into the Pawn Shop to serve as collateral for a loan. If underwritten, the ticket holder can withdraw funds loaned against this asset. On loan payback, the ticket holder receives the NFT collateral back. If the ticket is marked closed, the collateral has been withdrawn.\\n'
                )
            );
    }

}