pragma solidity 0.8.6;

import './interfaces/IPawnLoans.sol';
import './PawnShopNFT.sol';
import './descriptors/PawnShopNFTDescriptor.sol';

contract PawnLoans is PawnShopNFT, IPawnLoans {

    constructor(
        NFTPawnShop _pawnShop,
        PawnShopNFTDescriptor _descriptor
        ) 
        PawnShopNFT("Pawn Loans", "PWNL", _pawnShop, _descriptor) {}

    function pawnShopTransferLoan(address from, address to, uint256 loanId) pawnShopOnly() override external{
        _transfer(from, to, loanId);
    }
}