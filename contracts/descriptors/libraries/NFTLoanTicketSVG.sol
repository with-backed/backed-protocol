pragma solidity 0.8.6;
import 'base64-sol/base64.sol';
import '../../interfaces/ITicketTypeSpecificSVGHelper.sol';


library NFTLoanTicketSVG {

    struct SVGParams{
        // "Borrow" or "Lend"
        string nftType;
        // The Token Id, which is also the Id of the associated loan in NFTLoanFacilitator
        string id;
        // Human readable status, see {PopulateSVGParams-loanStatus}
        string status;
        // The approximate APR loan interest rate
        string interestRate;
        // The contract address of the ERC20 loan asset
        string loanAssetContract;
        // The contract address of the ERC20 loan asset, shortened for display
        string loanAssetContractPartial;
        // The symbol of the ERC20 loan asset
        string loanAssetSymbol;
        // The contract address of the ERC721 collateral asset
        string collateralContract;
        // The contract address of the ERC721 collateral asset, shortened for display
        string collateralContractPartial;
        // Symbol of the ERC721 collateral asset
        string collateralAssetSymbol;
        // TokenId of the ERC721 collateral asset
        string collateralId;
        // The loan amount, in loan asset units
        string loanAmount;
        // The interest accrued so far on the loan, in loan asset units
        string interestAccrued;
        // 
        string endDateTime;
    }

    // @notice returns an SVG image as a string. The SVG image is specific to the SVGParams
    function generateSVG(SVGParams memory params, ITicketTypeSpecificSVGHelper typeSpecificHelper) 
    internal pure 
    returns (string memory svg) 
    {
        return string(
                abi.encodePacked(
                    stylesAndBackground(
                        typeSpecificHelper,
                        params.loanAssetContract,
                        params.collateralContract
                    ),
                    typeSpecificHelper.typeSpecificDetails(
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
                        params.endDateTime
                    ),
                    '</text></svg>'
                )
            );
    }

    function stylesAndBackground(
        ITicketTypeSpecificSVGHelper typeSpecificHelper,
        string memory loanAsset,
        string memory collateralAsset) 
        private pure returns (string memory) {
        return string(
            abi.encodePacked(
        '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" ',
        'x="0px" y="0px" viewBox="0 0 480 480" width="480" height="480" xml:space="preserve">',
        '<style type="text/css">',
            '.st0{fill:url(#wash);fill-opacity:0.7;}',
            '.st1{opacity:0.8;fill-rule:evenodd;clip-rule:evenodd;fill:#FFFFFF;enable-background:new;}',
            '.st2{font-family: serif;}',
            '.st4{margin: 6px; font-size: 36px; letter-spacing: 1.8px;}',
            '.st5{fill:none;}',
            '.st6{font-family: sans-serif; font-weight: bold;}',
            '.st7{font-size:14px;}',
            '.st8{font-family: sans-serif;}',
            '.outer {width: 43px; height: 360px; position: relative; display: inline-block; margin: 0 15px;}',
	        '.inner {position: absolute; top: 50%; left: 50%;}',
            typeSpecificHelper.backgroundColorsStyles(loanAsset, collateralAsset),
        '</style>',
        '<defs>',
            '<radialGradient id="wash" cx="120" cy="40" r="140" ',
                'gradientTransform="skewY(5)" gradientUnits="userSpaceOnUse">',
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

    function collateralInfo(
        string memory collateralAssetPartial,
        string memory collateralAssetSymbol,
        string memory collateralId
        ) internal pure returns (string memory svg) {
        return string(abi.encodePacked(
            '<tspan x="0" y="108" class="st6 st7">collateral nft </tspan><tspan x="90" y="108" class="st8 st7"> (',
            collateralAssetSymbol,
            ') ',
            collateralAssetPartial,
            '</tspan>',
            '<tspan x="0" y="144" class="st6 st7">collateral ID </tspan><tspan x="86" y="144" class="st8 st7">',
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
        string memory endDateTime
    ) private pure returns (string memory){
        return string(
            abi.encodePacked(
                '<tspan x="0" y="0" class="st6 st7">loan amount</tspan><tspan x="86" y="0" class="st8 st7">',
                loanAmount,
                ' ',
                loanAssetSymbol,
                '</tspan>',
                '<tspan x="0" y="36" class="st6 st7">interest rate</tspan><tspan x="83" y="36" class="st8 st7">',
                interestRate,
                '</tspan>'
                '<tspan x="0" y="72" class="st6 st7">status</tspan><tspan x="45" y="72" class="st8 st7">',
                status,
                '</tspan>',
                '<tspan x="0" y="180" class="st6 st7">interest accrued</tspan><tspan x="111" y="180" class="st8 st7">',
                interestAccrued,
                ' ',
                loanAssetSymbol,
                '</tspan>',
                '<tspan x="0" y="216" class="st6 st7">loan asset </tspan><tspan x="76" y="216" class="st8 st7"> (',
                loanAssetSymbol,
                ') ',
                loanAssetPartial,
                '</tspan>',
                '<tspan x="0" y="252" class="st6 st7">end date</tspan><tspan x="68" y="252" class="st8 st7">',
                endDateTime,
                '</tspan>'
            )
        );
    }
}
