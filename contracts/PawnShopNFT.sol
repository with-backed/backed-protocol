pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import './descriptors/PawnShopNFTDescriptor.sol';
import './interfaces/IMintable.sol';

contract PawnShopNFT is ERC721Enumerable, IMintable {
    NFTPawnShop public immutable pawnShop;
    PawnShopNFTDescriptor public immutable descriptor;

    modifier pawnShopOnly(){ 
        require(msg.sender == address(pawnShop), "PawnLoans: Forbidden");
        _; 
    }

    constructor(
        string memory name, 
        string memory symbol, 
        NFTPawnShop _pawnShop, 
        PawnShopNFTDescriptor _descriptor) 
        ERC721(name, symbol) 
    {
        pawnShop = _pawnShop;
        descriptor = _descriptor;
    }

    function mint(address to, uint256 tokenId) pawnShopOnly() override external {
        _safeMint(to, tokenId);
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        return descriptor.uri(pawnShop, tokenId);
    }
}