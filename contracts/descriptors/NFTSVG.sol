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
                    generateSvgHead(params.nftType, params.id, params.loanAssetColor, params.collateralAssetColor),
                    svgStatusAndRate(params.status, params.interestRate),
                    svgAssetsInfo(
                        params.loanAssetContract,
                        params.loanAssetContractPartial,
                        params.loanAssetSymbol,
                        params.collateralContract,
                        params.collateralContractPartial,
                        params.collateralAssetSymbol, params.collateralId),
                    amountsSvg(params.loanAmount, params.interestAccrued, params.loanAssetSymbol, params.endBlock)
                ));
    }

    function generateSvgHead(
        string memory nftType,
        string memory id,
        string memory loanAssetColor,
        string memory collateralAssetColor) 
        private pure returns (string memory) {
        return string(
            abi.encodePacked(
        '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 300 488" width="300" height="488" xml:space="preserve">',
        '<style type="text/css">',
            '.st0{fill:#FFFFFF; opacity:0.7;}',
            '.st1{font-family:sans-serif;}',
            '.st2{font-size:14px;}',
            '.st3{fill: purple;}',
            '.st4{fill: blue;}',
            '.st6{font-family:sans-serif; font-weight:bold; font-size: 18px;}',
            '.st8{fill:url(#wash);}',
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
            '<radialGradient id="wash" cx="120" cy="40" r="140" gradientTransform="skewY(30)" gradientUnits="userSpaceOnUse">',
                '<stop  offset="0%" class="highlight-offset"/>',
                '<stop  offset="100%" class="highlight-hue"/>',
                '<animate attributeName="r" values="200;320;220;320;200" dur="15s" repeatCount="indefinite"/>',
                '<animate attributeName="cx" values="120;220;160;120;60;120" dur="15s" repeatCount="indefinite"/>',
                '<animate attributeName="cy" values="40;300;40;100;390;40" dur="15s" repeatCount="indefinite"/>',
            '</radialGradient>',
        '</defs>',
        '<use xlink:href="#:example" x="20" y="20"></use>',
        '<rect x="0" y="0" rx="10" ry="10" width="300" height="488" class="st8"/>',
        '<text x="300" y="90" mask="url(#mask-marquee)"><a href="https://nftpawnshop.net/v/',
        id,
        '" target="_blank"> <tspan class="st1 st2 st4"> https://nftpawnshop.net/v/',
        id,
            '</tspan></a><animate attributeName="x" values="300;-200" dur="10s" repeatCount="indefinite"/></text>'
        '<text x="300" y="90" class="st1 st2 st3" mask="url(#mask-marquee)">',
        keccak256(abi.encodePacked((nftType))) == keccak256(abi.encodePacked(('ticket'))) ? 'Ticket entitles owner to loaned funds' : 'Entitles owner to repayment or collateral',
            '<animate attributeName="x" values="300;-200" dur="10s" begin="4s" repeatCount="indefinite"/></text>',
        '<rect x="20" y="20" class="st0" width="260" height="50"/>',
        '<rect x="20" y="100" class="st0" width="260" height="40"/>',
        '<rect x="20" y="141" class="st0" width="260" height="40"/>',
        '<rect x="20" y="182" class="st0" width="260" height="40"/>',
        '<rect x="20" y="223" class="st0" width="260" height="40"/>',
        '<rect x="20" y="264" class="st0" width="260" height="40"/>',
        '<rect x="20" y="305" class="st0" width="260" height="40"/>',
        '<rect x="20" y="346" class="st0" width="260" height="40"/>',
        '<rect x="20" y="387" class="st0" width="260" height="40"/>',
        '<rect x="20" y="428" class="st0" width="260" height="40"/>',
        '<text transform="matrix(1 0 0 1 102 50)" class="st3 st6">pawn ',
        nftType,
        '</text>',
        '<text transform="matrix(1 0 0 1 35 125)"><tspan x="0" y="0" class="st1 st2">pawn ',
        nftType, 
        ' ID</tspan><tspan x="96" y="0" class="st4 st1 st2">',
        id,
        '</tspan></text>'
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

    function svgAssetsInfo(
        string memory loanAssetContract,
        string memory loanAssetContractPartial,
        string memory loanAssetSymbol,
        string memory collateralContract,
        string memory collateralAssetPartial,
        string memory collateralAssetSymbol,
        string memory collateralId
        ) internal pure returns (string memory svg) {
        return string(abi.encodePacked(
            '<text transform="matrix(1 0 0 1 35 248)"><tspan x="0" y="0" class="st1 st2">loan asset</tspan><a href="https://etherscan.io/token/',
            loanAssetContract,
            '" target="_blank"><tspan x="76" y="0" class="st4 st1 st2">(',
            loanAssetSymbol,
            ') ', 
            loanAssetContractPartial,
            '</tspan></a></text>',
            '<text transform="matrix(1 0 0 1 35 289)"><tspan x="0" y="0" class="st1 st2">collateral address</tspan><a href="https://etherscan.io/token/',
            collateralContract,
            '" target="_blank"><tspan x="120" y="0" class="st4 st1 st2">(',
            collateralAssetSymbol,
            ') ', 
            collateralAssetPartial,
            '</tspan></a></text>',
            '<text transform="matrix(1 0 0 1 35 330)"><tspan x="0" y="0" class="st1 st2">collateral ID</tspan><tspan x="82" y="0" class="st3 st1 st2">',
            collateralId,
            '</tspan></text>'
        ));
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

