pragma solidity ^0.8.2;

import './interfaces/IPawnLoans.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PawnLoans is ERC721, IPawnLoans {
    address public pawnShop;
    mapping(uint256 => bool) public override loanPaidBack;
    mapping(uint256 => bool) public override collateralSeized;

    constructor(address _pawnShop) ERC721("Pawn Loans", "PWNL") {
        pawnShop = _pawnShop;
    }

    modifier pawnShopOnly(){ 
        require(msg.sender == pawnShop, "PawnLoans: Forbidden");
        _; 
    }

    function mintLoan(address to, uint256 tokenId) pawnShopOnly override external {
        _mint(to, tokenId);
    }
    function transferLoan(address from, address to, uint256 loanId) pawnShopOnly override external{
        _transfer(from, to, loanId);
    }

    function setLoanPaidBack(uint256 loanId) pawnShopOnly override external {
        loanPaidBack[loanId] = true;
    }

    function setCollateralSeized(uint256 loanId) pawnShopOnly override external {
        collateralSeized[loanId] = true;
    }

}