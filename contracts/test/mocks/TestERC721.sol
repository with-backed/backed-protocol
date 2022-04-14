// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TestERC721 is ERC721 {
    using Strings for uint256;

    uint256 private _nonce = 999;

	constructor() ERC721("TestERC721", "TEST") {
    }

    function mint() external returns (uint256 id) {
        id = mintTo(msg.sender);
    }

    function mintTo(address to) public returns (uint256) {
        _mint(to, ++_nonce);
        return _nonce;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return "";
    }
}