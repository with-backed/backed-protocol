// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    using Strings for uint256;

    uint256 private _nonce = 1000;

	constructor() ERC721("TestERC721", "TEST") {
    }

    function mint() external returns (uint256 id) {
        id = mintTo(msg.sender);
    }

    function mintTo(address to) public returns (uint256 id) {
        _mint(to, id = _nonce++);
    }
}