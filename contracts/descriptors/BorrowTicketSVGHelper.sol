pragma solidity 0.8.6;

import './TicketTypeSpecificSVGHelper.sol';

contract BorrowTicketSVGHelper is TicketTypeSpecificSVGHelper {
    function backgroundColorsStyles(string memory collateralAsset, string memory loanAsset) external pure override returns (string memory){
        return colorStyles(collateralAsset, loanAsset);
    }

    function typeSpecificDetails(string memory id) external pure override returns (string memory){
        return string(abi.encodePacked(
            '<path class="st1" d="M60,60h360v16.6c-7.8,0-14.2,6.4-14.2,14.2c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2',
            'c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2',
            'c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2',
            'c0,7.8,6.4,14.2,14.2,14.2v14.2c-7.8,0-14.2,6.4-14.2,14.2c0,7.8,6.4,14.2,14.2,14.2V375c-7.8,0-14.2,6.4-14.2,14.2',
            'c0,7.8,6.4,14.2,14.2,14.2V420H60V60z M136.5,85.3h-4.8v309.2h4.8V85.3z"/>',
            '<foreignObject x="62" y="60" width="60" height="360">',
                '<div xmlns="http://www.w3.org/1999/xhtml" class="outer">',
                    '<div class="inner rotate"><span class="st4">BRWT</span><span class="st4">#',
                    id,
                    '</span></div>',
                '</div>',
            '</foreignObject>',
            '<rect x="160.4" y="106.1" class="st5" width="238.6" height="305.3"/>',
            '<text transform="matrix(1 0 0 1 160 120)">'
        ));
    }
}