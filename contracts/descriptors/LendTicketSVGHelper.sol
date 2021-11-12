pragma solidity 0.8.6;

import './TicketTypeSpecificSVGHelper.sol';

contract LendTicketSVGHelper is TicketTypeSpecificSVGHelper {
    /// See {TicketTypeSpecificSVGHelper-backgroundColorsStyles}
    function backgroundColorsStyles(string memory collateralAsset, string memory loanAsset) external pure override returns (string memory){
        return colorStyles(loanAsset, collateralAsset);
    }

    /// See {TicketTypeSpecificSVGHelper-typeSpecificDetails}
    function typeSpecificDetails(string memory id) external pure override returns (string memory){
        return string(abi.encodePacked(
            '<path class="st1" d="M420,420H70v-17.6c-7.8,0-14.2-6.4-14.2-14.2c0-7.8,6.4-14.2,14.2-14.2v-14.2c-7.8,0-14.2-6.4-14.2-14.2',
            'c0-7.8,6.4-14.2,14.2-14.2v-14.2c-7.8,0-14.2-6.4-14.2-14.2c0-7.8,6.4-14.2,14.2-14.2v-14.2c-7.8,0-14.2-6.4-14.2-14.2',
            'c0-7.8,6.4-14.2,14.2-14.2v-14.2c-7.8,0-14.2-6.4-14.2-14.2c0-7.8,6.4-14.2,14.2-14.2v-14.2c-7.8,0-14.2-6.4-14.2-14.2',
            'c0-7.8,6.4-14.2,14.2-14.2v-14.2c-7.8,0-14.2-6.4-14.2-14.2c0-7.8,6.4-14.2,14.2-14.2V104c-7.8,0-14.2-6.4-14.2-14.2',
            'c0-7.8,6.4-14.2,14.2-14.2V60h350V420z M343.5,393.7h4.8V84.6h-4.8V393.7z"/>',
            '<foreignObject x="345" y="60" width="60" height="360">',
                '<div xmlns="http://www.w3.org/1999/xhtml" class="outer">',
                    '<div class="inner rotate"><span class="st4">LNDT</span><span class="st4">#',
                    id,
                    '</span></div>',
                    
                '</div>',
            '</foreignObject>'
            '<rect x="160.4" y="106.1" class="st5" width="238.6" height="305.3"/>',
            '<text transform="matrix(1 0 0 1 98 120)">'
        ));
    }
}