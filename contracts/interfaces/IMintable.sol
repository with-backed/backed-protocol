pragma solidity 0.8.6;

interface IMintable {
    function mint(address to, uint256 tokenId) external;
}