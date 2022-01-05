pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import './descriptors/NFTLoansTicketDescriptor.sol';
import './interfaces/IERC721Mintable.sol';

contract NFTLoanTicket is ERC721, IERC721Mintable {
    NFTLoanFacilitator public immutable nftLoanFacilitator;
    NFTLoansTicketDescriptor public immutable descriptor;

    modifier loanFacilitatorOnly(){ 
        require(msg.sender == address(nftLoanFacilitator), "NFTLoanTicket: only loan facilitator");
        _; 
    }

    /// @dev Sets the values for {name} and {symbol} and {nftLoanFacilitator} and {descriptor}.
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

    /// See {IERC721Mintable-mint}.
    function mint(address to, uint256 tokenId) loanFacilitatorOnly() override external {
        _mint(to, tokenId);
    }

    /// @notice returns a base64 encoded data uri containing the token metadata in JSON format
    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        require(_exists(tokenId), "NFTLoanTicket: URI query for nonexistent token");
        return descriptor.uri(nftLoanFacilitator, tokenId);
    }
}