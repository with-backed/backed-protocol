pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CryptoPunks is ERC721 {
    using Strings for uint256;

    uint256 private _nonce = 999;

	constructor() ERC721("CryptoPunks", "PUNKS") {
    }

    function mint() external returns (uint256 id) {
        id = mintTo(msg.sender);
    }

    function mintTo(address to) public returns (uint256) {
        _safeMint(to, ++_nonce, "");
        return _nonce;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://wrappedpunks.com:3000/api/punks/metadata/";
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }
}