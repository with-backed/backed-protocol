pragma solidity 0.8.6;

interface TypeSpecificSVGHelper {
    function backgroundColorsStyles(string memory collateralAssetColor, string memory loanAssetColor) external pure virtual returns (string memory);
    function typeSpecificDetails(string memory id) external pure virtual returns (string memory);
}