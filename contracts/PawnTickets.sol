pragma solidity 0.8.6;

import './PawnShopNFT.sol';
import './descriptors/PawnShopNFTDescriptor.sol';

contract PawnTickets is PawnShopNFT {

    constructor(
        NFTPawnShop _pawnShop,
        PawnShopNFTDescriptor _descriptor) 
        PawnShopNFT("Pawn Tickets", "PWNT", _pawnShop, _descriptor) {}
}