pragma solidity 0.8.6;

import './libraries/PawnShopSVG.sol';
import '../interfaces/TypeSpecificSVGHelper.sol';

contract PawnTicketSVG is TypeSpecificSVGHelper {
    function backgroundColorsStyles(string memory collateralAssetColor, string memory loanAssetColor) external pure override returns (string memory){
        return string(
            abi.encodePacked(
                '.highlight-hue{stop-color:hsl(',
                collateralAssetColor,
                ',100%,85%)}',
                '.highlight-offset{stop-color:hsl(',
                loanAssetColor,
                ',100%,85%)}'
            )
        );
    }

    function typeSpecificDetails(string memory id) external pure override returns (string memory){
        return string(abi.encodePacked(
            '<path class="st1" d="M60,60h360v16.6c-7.8,0-14.2,6.4-14.2,14.2c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2',
            'c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2',
            'c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2',
            'c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2c0,7.8,6.4,14.2,14.2,14.2V375c-7.8,0-14.2,6.4-14.2,14.2',
            'c0,7.8,6.4,14.2,14.2,14.2V420H60V60z M136.5,85.3h-4.8v309.2h4.8V85.3z"/>',
            '<text transform="matrix(0 -1 1 0 111 350)" class="st2 st3 st4">PWNT #',
            id,
            '</text>',
            '<rect x="160.4" y="106.1" class="st5" width="238.6" height="305.3"/>',
            '<text transform="matrix(1 0 0 1 160 134)">'
        ));
    }
}