import './PawnShopNFTDescriptor.sol';

contract PawnLoanDescriptor is PawnShopNFTDescriptor {
    constructor(TypeSpecificSVGHelper _svgHelper) PawnShopNFTDescriptor("loan", _svgHelper) {
    }

    function generateDescription() internal virtual override pure returns (string memory) {
        return "loan";
    }

}