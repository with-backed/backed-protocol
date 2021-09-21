import './PawnShopNFTDescriptor.sol';

contract PawnTicketDescriptor is PawnShopNFTDescriptor {
    constructor(TypeSpecificSVGHelper _svgHelper) PawnShopNFTDescriptor("ticket", _svgHelper) {
    }

    function generateDescription() internal virtual override pure returns (string memory) {
        return "ticket";
    }

}