pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import './descriptors/NFTLoansTicketDescriptor.sol';
import './interfaces/IMintable.sol';

contract NFTLoanTicket is ERC721Enumerable, IMintable {
    NFTLoanFacilitator public immutable nftLoanFacilitator;
    NFTLoansTicketDescriptor public immutable descriptor;

    modifier loanFacilitatorOnly(){ 
        require(msg.sender == address(nftLoanFacilitator), "NFTLoanTicket: only loan facilitator");
        _; 
    }

    constructor(
        string memory name, 
        string memory symbol, 
        NFTLoanFacilitator _nftLoanFacilitator, 
        NFTLoansTicketDescriptor _descriptor) 
        ERC721(name, symbol) 
    {
        nftLoanFacilitator = _nftLoanFacilitator;
        descriptor = _descriptor;
    }

    function mint(address to, uint256 tokenId) loanFacilitatorOnly() override external {
        require(!_exists(tokenId), "NFTLoanTicket: token with tokenId already exists");
        _mint(to, tokenId);
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return descriptor.uri(nftLoanFacilitator, tokenId);
    }
}