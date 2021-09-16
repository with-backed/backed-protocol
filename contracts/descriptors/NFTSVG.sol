pragma solidity 0.8.6;
import 'base64-sol/base64.sol';

library NFTSVG{

    struct SVGParams{
        string nftType; // "ticket" or "loan"
        string collateralAssetColor;
        string loanAssetColor;
        string id;
        string status;
        string interestRate;
        string loanAssetContract;
        string loanAssetContractPartial;
        string loanAssetSymbol;
        string collateralContract;
        string collateralContractPartial;
        string collateralAssetSymbol;
        string collateralId;
        string loanAmount;
        string interestAccrued;
        string endBlock;
    }

    function generateSVG(SVGParams memory params) internal pure returns (string memory svg) {
        return string(
                abi.encodePacked(
                    stylesAndBackground(
                        params.nftType,
                        params.id,
                        params.loanAssetColor,
                        params.collateralAssetColor
                    ),
                    ticketTypeDetails(
                        params.id
                    ),
                    collateralInfo(
                        params.collateralContractPartial,
                        params.collateralAssetSymbol,
                        params.collateralId
                    ),
                    details(
                        params.loanAmount,
                        params.loanAssetSymbol,
                        params.interestRate,
                        params.status,
                        params.interestAccrued,
                        params.loanAssetContractPartial,
                        params.endBlock
                    ),
                    '</text></svg>'
                )
            );
        // return string(
        //         abi.encodePacked(
        //             stylesAndBackground(params.nftType, params.id, params.loanAssetColor, params.collateralAssetColor),
        //             ticketTypeDetails(id),
        //             svgStatusAndRate(params.status, params.interestRate),
        //             svgAssetsInfo(
        //                 params.loanAssetContract,
        //                 params.loanAssetContractPartial,
        //                 params.loanAssetSymbol,
        //                 params.collateralContract,
        //                 params.collateralContractPartial,
        //                 params.collateralAssetSymbol, params.collateralId),
        //             amountsSvg(params.loanAmount, params.interestAccrued, params.loanAssetSymbol, params.endBlock)
        //         ));
    }

    function stylesAndBackground(
        string memory nftType,
        string memory id,
        string memory loanAssetColor,
        string memory collateralAssetColor) 
        private pure returns (string memory) {
        return string(
            abi.encodePacked(
        '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 480 480" width="480" height="480" xml:space="preserve">',
        '<style type="text/css">',
            '.st0{fill:url(#wash);fill-opacity:0.7;}',
            '.st1{opacity:0.8;fill-rule:evenodd;clip-rule:evenodd;fill:#FFFFFF;enable-background:new;}',
            '.st2{font-family: serif;}',
            '.st3{font-size:40px;}',
            '.st4{letter-spacing:4;}',
            '.st5{fill:none;}',
            '.st6{font-family: sans-serif; font-weight: bold;}',
            '.st7{font-size:13px;}',
            '.st8{font-family: sans-serif;}',
            '.highlight-hue{stop-color:hsl(',
            collateralAssetColor,
            ',100%,85%)}',
            '.highlight-offset{stop-color:hsl(',
            loanAssetColor,
            ',100%,85%)}',
        '</style>',
        '<defs>',
            '<mask id="mask-marquee">',
            '<rect x="20" y="70" width="260" height="30" fill="#fff"/>',
            '</mask>',
            '<mask id="mask-amount">',
            '<rect x="124" y="341" width="146" height="30" fill="#fff"/>',
            '</mask>',
            '<mask id="mask-accrued">',
            '<rect x="146" y="382" width="124" height="30" fill="#fff"/>',
            '</mask>',
            '<radialGradient id="wash" cx="120" cy="40" r="140" gradientTransform="skewY(5)" gradientUnits="userSpaceOnUse">',
                '<stop  offset="0%" class="highlight-offset"/>',
                '<stop  offset="100%" class="highlight-hue"/>',
                '<animate attributeName="r" values="300;520;320;420;300" dur="25s" repeatCount="indefinite"/>',
                '<animate attributeName="cx" values="120;420;260;120;60;120" dur="25s" repeatCount="indefinite"/>',
                '<animate attributeName="cy" values="40;300;40;250;390;40" dur="25s" repeatCount="indefinite"/>',
            '</radialGradient>',
        '</defs>',
        '<rect x="0" class="st0" width="480" height="480"/>'
        ));
    }

    function ticketTypeDetails(string memory id) private pure returns (string memory){
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

    function svgStatusAndRate(string memory status, string memory interestRate) private pure returns (string memory svg) {
        return string(abi.encodePacked(
            '<text transform="matrix(1 0 0 1 35 166)"><tspan x="0" y="0" class="st1 st2">status</tspan><tspan x="47" y="0" class="st3 st1 st2">',
            status,
            '</tspan></text>',
            '<text transform="matrix(1 0 0 1 35 207)"><tspan x="0" y="0" class="st1 st2">interest rate</tspan><tspan x="80" y="0" class="st3 st1 st2">',
            interestRate,
            '</tspan></text>'
        ));
    }

    function collateralInfo(
        string memory collateralAssetPartial,
        string memory collateralAssetSymbol,
        string memory collateralId
        ) internal pure returns (string memory svg) {
        return string(abi.encodePacked(
            '<tspan x="0" y="0" class="st6 st7">collateral nft </tspan><tspan x="87.3" y="0" class="st8 st7"> (',
            collateralAssetSymbol,
            ') ',
            collateralAssetPartial,
            '</tspan>',
            '<tspan x="0" y="30.9" class="st6 st7">collateral ID </tspan><tspan x="83.5" y="30.9" class="st8 st7">',
            collateralId,
            '</tspan>'
        ));
    }

    function details(
        string memory loanAmount,
        string memory loanAssetSymbol,
        string memory interestRate,
        string memory status,
        string memory interestAccrued,
        string memory loanAssetPartial,
        string memory endBlock
    ) private pure returns (string memory){
        return string(
            abi.encodePacked(
                '<tspan x="0" y="61.8" class="st6 st7">loan amount</tspan><tspan x="83.4" y="61.8" class="st8 st7">',
                loanAmount,
                ' ',
                loanAssetSymbol,
                '</tspan>',
                '<tspan x="0" y="92.6" class="st6 st7">interest rate</tspan><tspan x="80.3" y="92.6" class="st8 st7">',
                interestRate,
                '</tspan>'
                '<tspan x="0" y="123.5" class="st6 st7">status</tspan><tspan x="41.3" y="123.5" class="st8 st7">',
                status,
                '</tspan>',
                '<tspan x="0" y="154.4" class="st6 st7">interest accrued</tspan><tspan x="108.4" y="154.4" class="st8 st7">',
                interestAccrued,
                ' ',
                loanAssetSymbol,
                '</tspan>',
                '<tspan x="0" y="185.3" class="st6 st7">loan asset </tspan><tspan x="72.5" y="185.3" class="st8 st7"> (',
                loanAssetSymbol,
                ') ',
                loanAssetPartial,
                '</tspan>',
                '<tspan x="0" y="216.1" class="st6 st7">end block</tspan><tspan x="65.5" y="216.1" class="st8 st7">',
                endBlock,
                '</tspan>'
            )
        );
    }
    
    function amountsSvg(string memory loanAmount, string memory interestAccrued, string memory loanAssetSymbol, string memory endBlock) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<text transform="matrix(1 0 0 1 35 371)"><tspan x="0" y="0" class="st1 st2">loan amount</tspan></text>',
                '<text x="300" y="371" class="st3 st1 st2" mask="url(#mask-amount)">',
                loanAmount,
                ' ',
                loanAssetSymbol,
                    '<animate attributeName="x" values="280;-60" dur="8s" repeatCount="indefinite"/></text>',
                '<text x="300" y="371" class="st3 st1 st2" mask="url(#mask-amount)">',
                loanAmount,
                ' ',
                loanAssetSymbol,
                    '<animate attributeName="x" values="280;-60" dur="8s" begin="4s" repeatCount="indefinite"/></text>',
                '<text transform="matrix(1 0 0 1 35 412)"><tspan x="0" y="0" class="st1 st2">interest accrued</tspan></text>',
                '<text x="300" y="412" class="st3 st1 st2" mask="url(#mask-accrued)">',
                interestAccrued,
                ' ',
                loanAssetSymbol,
                    '<animate attributeName="x" values="280;-60" dur="8s" repeatCount="indefinite"/></text>',
                '<text x="300" y="412" class="st3 st1 st2" mask="url(#mask-accrued)">',
                interestAccrued,
                ' ',
                loanAssetSymbol,
                    '<animate attributeName="x" values="280;-60" dur="8s" begin="4s" repeatCount="indefinite"/></text>',
                '<text transform="matrix(1 0 0 1 35 453)"><tspan x="0" y="0" class="st1 st2">end block</tspan><tspan x="68" y="0" class="st3 st1 st2">',
                endBlock,
                '</tspan></text>',
                '</svg>'
            )
        );
    }
}

