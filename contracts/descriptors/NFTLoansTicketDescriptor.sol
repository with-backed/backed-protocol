pragma solidity 0.8.6;

import 'base64-sol/base64.sol';
import './../NFTLoanFacilitator.sol';
import "hardhat/console.sol";
import '../interfaces/IERC20Metadata.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import './libraries/NFTLoanTicketSVG.sol';
import './libraries/PopulateSVGParams.sol';

contract NFTLoansTicketDescriptor {
    string public nftType;
    ITicketTypeSpecificSVGHelper immutable public svgHelper;

    constructor(string memory _nftType, ITicketTypeSpecificSVGHelper _svgHelper) {
        nftType = _nftType;
        svgHelper = _svgHelper;
    }

    function uri(NFTLoanFacilitator nftLoanFacilitator, uint256 id)
        external
        view
        returns (string memory)
    {
        NFTLoanTicketSVG.SVGParams memory svgParams;
        svgParams.nftType = nftType;
        svgParams = PopulateSVGParams.populate(svgParams, nftLoanFacilitator, id);
        
        return generateDescriptor(svgParams);
    }

    function generateDescriptor(NFTLoanTicketSVG.SVGParams memory svgParams)
        private
        view
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    'data:application/json;base64,',
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                svgParams.nftType,
                                ' ticket',
                                ' #',
                                svgParams.id,
                                '", "description":"',
                                generateDescription(svgParams.id),
                                generateDescriptionDetails(
                                    svgParams.loanAssetContract,
                                    svgParams.loanAssetSymbol,
                                    svgParams.collateralContract, 
                                    svgParams.collateralAssetSymbol,
                                    svgParams.collateralId),
                                '", "image": "',
                                'data:image/svg+xml;base64,',
                                Base64.encode(bytes(NFTLoanTicketSVG.generateSVG(svgParams, svgHelper))),
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function generateDescription(string memory pawnTicketId) internal virtual pure returns (string memory) {}

    function generateDescriptionDetails(
        string memory loanAsset,
        string memory loanAssetSymbol,
        string memory collateralAsset,
        string memory collateralAssetSymbol,
        string memory collateralAssetId
        ) private pure returns (string memory){
            return string(
                abi.encodePacked(
                    'Collateral Address: ',
                    collateralAsset,
                    ' (',
                    collateralAssetSymbol,
                    ')\\n',
                    'Collateral ID: ',
                    collateralAssetId,
                    '\\n',
                    'Loan Asset Address: ',
                    loanAsset,
                    ' (',
                    loanAssetSymbol,
                    ')\\n',
                    'WARNING: Do your own research to verify the legitimacy of the assets releated to this ticket'
                )
            );
    }
}