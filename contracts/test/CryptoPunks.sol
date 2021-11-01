pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CryptoPunks is ERC721 {
    using Strings for uint256;

    uint256 private _nonce = 1;

	constructor() ERC721("Monarchs", "MNR") {
    }

    function mint() external {
        mintTo(msg.sender);
    }

    function mintTo(address to) public {
        _safeMint(to, _nonce++, "");
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmXuEFJVjQrHX7GRWY2WnbUP59re3WsyDLZoKqXvRPSxBY/";
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }
}