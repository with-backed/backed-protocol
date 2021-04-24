pragma solidity ^0.8.2;

interface IERC721Mintable {

    function mint(address to, uint256 tokenId) external;
}