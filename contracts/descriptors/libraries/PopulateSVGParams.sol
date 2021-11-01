pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import './DateTimeLibrary.sol';
import './UintStrings.sol';
import '../../NFTLoanFacilitator.sol';
import '../../interfaces/IERC20Metadata.sol';
import './HexStrings.sol';
import './NFTLoanTicketSVG.sol';


library PopulateSVGParams{
    
    // @notice Populates and returns the passed `svgParams` with loan info retrieved from
    // `nftLoanFacilitator` for `id`, the loan id
    function populate(NFTLoanTicketSVG.SVGParams memory svgParams, NFTLoanFacilitator nftLoanFacilitator, uint256 id)
        internal
        view
        returns (NFTLoanTicketSVG.SVGParams memory)
    {
        (bool closed, uint256 perSecondInterestRate, ,
        uint256 lastAccumulatedTimestamp, uint256 durationSeconds,
        uint256 loanAmount, uint256 collateralID, 
        address collateralAddress, address loanAsset) = nftLoanFacilitator.loanInfo(id);

        svgParams.id = Strings.toString(id);
        svgParams.status = loanStatus(lastAccumulatedTimestamp, durationSeconds, closed);
        svgParams.interestRate = interestRateString(nftLoanFacilitator, perSecondInterestRate); 
        svgParams.loanAssetContract = HexStrings.toHexString(uint160(loanAsset), 20);
        svgParams.loanAssetContractPartial = HexStrings.partialHexString(uint160(loanAsset), 6, 40);
        svgParams.loanAssetSymbol = loanAssetSymbol(loanAsset);
        svgParams.collateralContract = HexStrings.toHexString(uint160(collateralAddress), 20);
        svgParams.collateralContractPartial = HexStrings.partialHexString(uint160(collateralAddress), 6, 40);
        svgParams.collateralAssetSymbol = collateralAssetSymbol(collateralAddress);
        svgParams.collateralId = Strings.toString(collateralID);
        svgParams.loanAmount = loanAmountString(loanAmount, loanAsset);
        svgParams.interestAccrued = accruedInterest(nftLoanFacilitator, id, loanAsset);
        svgParams.endDateTime = lastAccumulatedTimestamp == 0 ? "n/a" 
        : endDateTime(lastAccumulatedTimestamp + durationSeconds);
        
        return svgParams;
    }

    function interestRateString(NFTLoanFacilitator nftLoanFacilitator, uint256 perSecondInterestRate) 
    private view 
    returns (string memory)
    {
        return UintStrings.decimalString(
            annualInterestRate(perSecondInterestRate),
            nftLoanFacilitator.INTEREST_RATE_DECIMALS() - 2,
            true
            );
    }

    function loanAmountString(uint256 amount, address asset) private view returns (string memory){
        return UintStrings.decimalString(amount, IERC20Metadata(asset).decimals(), false);
    }

    function loanAssetSymbol(address asset) private view returns (string memory){
        return IERC20Metadata(asset).symbol();
    }

    function collateralAssetSymbol(address asset) private view returns (string memory){
        return ERC721(asset).symbol();
    }

    function accruedInterest(NFTLoanFacilitator nftLoanFacilitator, uint256 loanId, address loanAsset) 
    private view 
    returns(string memory)
    {
        return UintStrings.decimalString(
            nftLoanFacilitator.interestOwed(loanId),
            IERC20Metadata(loanAsset).decimals(),
            false);
    }

    function annualInterestRate(uint256 perSecondInterest) private pure returns(uint256) {
        return perSecondInterest * 31_536_000;
    }

    function loanStatus(uint256 lastAccumulatedTimestamp, uint256 durationSeconds, bool closed) 
    view private 
    returns(string memory)
    {
        if(lastAccumulatedTimestamp == 0){
            return "active, awaiting underwriter";
        }

        if(closed){
            return "closed";
        }

        if(block.timestamp > (lastAccumulatedTimestamp + durationSeconds)){
            return "past due, accumulating interest";
        }

        return 'active, accumulating interest';
    }

    function endDateTime(uint256 endDateSeconds) private pure returns (string memory){
        (uint year, uint month, 
        uint day, uint hour, 
        uint minute, uint second) = BokkyPooBahsDateTimeLibrary.timestampToDateTime(endDateSeconds);
        return string(
            abi.encodePacked(
                Strings.toString(year),
                '-',
                Strings.toString(month),
                '-',
                Strings.toString(day),
                ' ',
                Strings.toString(hour),
                ':',
                Strings.toString(minute),
                ':',
                Strings.toString(second),
                ' UTC'
            )
        );
    } 
}