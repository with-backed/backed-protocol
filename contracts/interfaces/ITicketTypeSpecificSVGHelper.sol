pragma solidity 0.8.6;

interface ITicketTypeSpecificSVGHelper {
    // @notice returns a string of styles for use within an SVG
    // @param collateralAsset A string of the collateral asset address
    // @param loanAsset A string of the loan asset address
    function backgroundColorsStyles(
        string memory collateralAsset,
        string memory loanAsset
        ) 
        external pure 
        returns (string memory);

    // @notice returns a string of SVG elements
    // @param id The tokenId of the NFT thats SVG image is being generated
    function typeSpecificDetails(string memory id) external pure returns (string memory);
}