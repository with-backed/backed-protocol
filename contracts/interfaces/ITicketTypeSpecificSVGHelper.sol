pragma solidity 0.8.6;

interface ITicketTypeSpecificSVGHelper {
    function backgroundColorsStyles(string memory collateralAsset, string memory loanAsset) external pure returns (string memory);
    function typeSpecificDetails(string memory id) external pure returns (string memory);
}