pragma solidity ^0.8.2;

interface IERC721AdminTransferable {
	function adminTransferFrom(address from, address to, uint256 tokenId) external;
}