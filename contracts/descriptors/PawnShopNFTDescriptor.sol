pragma solidity 0.8.6;

import 'base64-sol/base64.sol';
import './../PawnShop.sol';
import "hardhat/console.sol";
import '../interfaces/IERC20.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import './NFTSVG.sol';
import './HexStrings.sol';
import './UintStrings.sol';


contract PawnShopNFTDescriptor {
    bytes32 immutable ticketTypeHash = keccak256(abi.encodePacked(("ticket")));

    function ticketURI(NFTPawnShop pawnShop, uint256 id)
        external
        view
        returns (string memory)
    {
        NFTSVG.SVGParams memory svgParams;
        svgParams.nftType = "ticket";
        return uri(svgParams, pawnShop, id);
    }

    function loanURI(NFTPawnShop pawnShop, uint256 id)
        external
        view
        returns (string memory)
    {
        NFTSVG.SVGParams memory svgParams;
        svgParams.nftType = "loan";
        return uri(svgParams, pawnShop, id);
    }

    function uri(NFTSVG.SVGParams memory svgParams, NFTPawnShop pawnShop, uint256 id)
        private
        view
        returns (string memory)
    {
        (bool closed, bool collateralSeized, uint256 perBlockInterestRate
        , , uint256 lastAccumulatedBlock, uint256 blockDuration,
        uint256 loanAmount, , uint256 collateralID, address loanAsset, address collateralAddress) = pawnShop.ticketInfo(id);

        require(keccak256(abi.encodePacked((svgParams.nftType))) == ticketTypeHash || lastAccumulatedBlock != 0, 'Invalid loan ID');

        svgParams.loanAssetColor = UintStrings.decimalString(uint8(keccak256(abi.encodePacked(loanAsset))[0]), 0, false);
        svgParams.collateralAssetColor = UintStrings.decimalString(uint8(keccak256(abi.encodePacked(collateralAddress))[0]), 0, false);
        svgParams.id = UintStrings.decimalString(id, 0, false);
        svgParams.status = loanStatus(lastAccumulatedBlock, blockDuration, closed, collateralSeized);
        svgParams.interestRate = interestRateString(pawnShop, perBlockInterestRate); 
        svgParams.loanAssetContract = HexStrings.toHexString(uint160(loanAsset), 20);
        svgParams.loanAssetContractPartial = HexStrings.partialHexString(uint160(loanAsset));
        svgParams.loanAssetSymbol = loanAssetSymbol(loanAsset);
        svgParams.collateralContract = HexStrings.toHexString(uint160(collateralAddress), 20);
        svgParams.collateralContractPartial = HexStrings.partialHexString(uint160(collateralAddress));
        svgParams.collateralAssetSymbol = collateralAssetSymbol(collateralAddress);
        svgParams.collateralId = UintStrings.decimalString(collateralID, 0, false);
        svgParams.loanAmount = loanAmountString(loanAmount, loanAsset);
        svgParams.interestAccrued = accruedInterest(pawnShop, id, loanAsset);
        svgParams.endBlock = lastAccumulatedBlock == 0 ? "n/a" : UintStrings.decimalString(lastAccumulatedBlock + blockDuration, 0, false);
        
        return generateDescriptor(svgParams);
    }

    function interestRateString(NFTPawnShop pawnShop, uint256 perBlockInterestRate) private view returns (string memory){
        return UintStrings.decimalString(perBlockInterestToAnnual(perBlockInterestRate), pawnShop.interestRateDecimals() - 2, true);
    }

    function loanAmountString(uint256 amount, address asset) private view returns (string memory){
        return UintStrings.decimalString(amount, IERC20(asset).decimals(), false);
    }

    function loanAssetSymbol(address asset) private view returns (string memory){
        return IERC20(asset).symbol();
    }

    function collateralAssetSymbol(address asset) private view returns (string memory){
        return ERC721(asset).symbol();
    }

    function accruedInterest(NFTPawnShop pawnShop, uint256 pawnTicketId, address loanAsset) private view returns(string memory){
        return UintStrings.decimalString(pawnShop.interestOwed(pawnTicketId), IERC20(loanAsset).decimals(), false);
    }

    function perBlockInterestToAnnual(uint256 perBlockInterest) private pure returns(uint256) {
        return perBlockInterest * 2252571; // block every 14s, (60/14)*60*24*365 ~= 2252571 blocks per year
    }

    function loanStatus(uint256 lastAccumulatedBlock, uint256 blockDuration, bool closed, bool collateralSeized) view private returns(string memory){
        if(lastAccumulatedBlock == 0){
            return "awaiting underwriter";
        }

        if(collateralSeized){
            return "collateral seized";
        }

        if(closed){
            return "repaid and closed";
        }

        if(block.number > (lastAccumulatedBlock + blockDuration)){
            return "past due";
        }

        return 'underwritten';
    }

    function generateDescriptor(NFTSVG.SVGParams memory svgParams)
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
                                'NFT Pawn Shop - ',
                                svgParams.nftType,
                                ' #',
                                svgParams.id,
                                '", "description":"',
                                generateDescription(
                                    svgParams.id,
                                    svgParams.nftType),
                                generateDescriptionDetails(
                                    svgParams.loanAssetContract,
                                    svgParams.loanAssetSymbol,
                                    svgParams.collateralContract, 
                                    svgParams.collateralAssetSymbol,
                                    svgParams.collateralId),
                                '", "image": "',
                                'data:image/svg+xml;base64,',
                                Base64.encode(bytes(NFTSVG.generateSVG(svgParams))),
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function generateDescription(
        string memory pawnTicketId,
        string memory nftType
        ) private view returns (string memory){
        if (keccak256(abi.encodePacked((nftType))) == ticketTypeHash){
            return generateTicketDescription();
        }
        return generateLoanDescription(pawnTicketId);
    }

    function generateLoanDescription(string memory pawnTicketId) private pure returns (string memory){
            return string(
                abi.encodePacked(
                    'This Pawn Shop Loan NFT was created when Pawn Shop Ticket #', 
                    pawnTicketId,
                    ' was underwritten. If the loan is paid back on time, the holder of this NFT is entitled to the loaned funds plus interest. If it is not paid back on time, the holder of this ticket is entitled to seize the NFT collateral.\\n'
                )
            );
    }

    function generateTicketDescription() private pure returns (string memory){
            return string(
                abi.encodePacked(
                    'This Pawn Shop Ticket NFT was created by the deposit an NFT into the Pawn Shop to serve as collateral for a loan. If underwritten, the ticket holder can withdraw funds loaned against this asset. On loan payback, the ticket holder receives the NFT collateral back. If the ticket is marked closed, the collateral has been withdrawn.\\n'
                )
            );
    }

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