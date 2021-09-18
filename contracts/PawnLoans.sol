pragma solidity 0.8.6;

import './interfaces/IPawnLoans.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import './descriptors/PawnShopNFTDescriptor.sol';

import "hardhat/console.sol";

contract PawnLoans is ERC721, IPawnLoans {
    address public immutable pawnShop;
    address private immutable _tokenDescriptor;

    constructor(address _pawnShop, address _tokenDescriptor_) ERC721("Pawn Loans", "PWNL") {
        pawnShop = _pawnShop;
        _tokenDescriptor = _tokenDescriptor_;
    }

    modifier pawnShopOnly(){ 
        require(msg.sender == pawnShop, "PawnLoans: Forbidden");
        _; 
    }

    function mintLoan(address to, uint256 tokenId) pawnShopOnly() override external {
        _mint(to, tokenId);
    }
    function transferLoan(address from, address to, uint256 loanId) pawnShopOnly() override external{
        _transfer(from, to, loanId);
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        return  PawnShopNFTDescriptor(_tokenDescriptor).loanURI(NFTPawnShop(pawnShop), tokenId);
    }
}