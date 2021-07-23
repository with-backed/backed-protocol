pragma solidity 0.8.6;

import './interfaces/IPawnTickets.sol';
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import './descriptors/PawnShopNFTDescriptor.sol';

import "hardhat/console.sol";

contract PawnTickets is ERC721Enumerable, IPawnTickets {
    address public immutable pawnShop;
    address private immutable _tokenDescriptor;

    constructor(address _pawnShop, address _tokenDescriptor_) ERC721("Pawn Tickets", "PWNT") {
        pawnShop = _pawnShop;
        _tokenDescriptor = _tokenDescriptor_;
    }

    function mintTicket(address to, uint256 tokenId) override external {
        require(msg.sender == pawnShop, "PawnTickets: Forbidden");
        _mint(to, tokenId);
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        return  PawnShopNFTDescriptor(_tokenDescriptor).ticketURI(NFTPawnShop(pawnShop), tokenId);
    }
}