pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract CryptoPunks is ERC721 {

    uint256 private _nonce;

	constructor() ERC721("CryptoPunks", "PUNKS") {
    }

    function mint() external {
        _safeMint(msg.sender, ++_nonce, "");
    }

}