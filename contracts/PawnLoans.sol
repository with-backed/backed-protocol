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

    function mintLoan(address to, uint256 tokenId) override external {
        require(msg.sender == pawnShop, "PawnLoans: Forbidden");
        _mint(to, tokenId);
    }
    function transferLoan(address from, address to, uint256 loanId) override external{
        require(msg.sender == pawnShop, "PawnLoans: Forbidden");
        _transfer(from, to, loanId);
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        return  PawnShopNFTDescriptor(_tokenDescriptor).loanURI(NFTPawnShop(pawnShop), tokenId);
    }
}