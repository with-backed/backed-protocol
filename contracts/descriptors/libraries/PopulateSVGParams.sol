// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import './BokkyPooBahsDateTimeLibrary.sol';
import './UintStrings.sol';
import '../../interfaces/INFTLoanFacilitator.sol';
import '../../interfaces/IERC20Metadata.sol';
import './HexStrings.sol';
import './NFTLoanTicketSVG.sol';


library PopulateSVGParams{
    /**
     * @notice Populates and returns the passed `svgParams` with loan info retrieved from
     * `nftLoanFacilitator` for `id`, the loan id
     * @param svgParams The svg params to populate, which already has `nftType` populated from NFTLoansTicketDescriptor
     * @param nftLoanFacilitator The loan facilitator contract to get loan info from for loan `id`
     * @param id The id of the loan
     * @return `svgParams`, with all values now populated
     */
    function populate(NFTLoanTicketSVG.SVGParams memory svgParams, INFTLoanFacilitator nftLoanFacilitator, uint256 id)
        internal
        view
        returns (NFTLoanTicketSVG.SVGParams memory)
    {
        INFTLoanFacilitator.Loan memory loan = nftLoanFacilitator.loanInfoStruct(id);

        svgParams.id = Strings.toString(id);
        svgParams.status = loanStatus(loan.lastAccumulatedTimestamp, loan.durationSeconds, loan.closed);
        svgParams.interestRate = interestRateString(nftLoanFacilitator, loan.perAnnumInterestRate); 
        svgParams.loanAssetContract = HexStrings.toHexString(uint160(loan.loanAssetContractAddress), 20);
        svgParams.loanAssetSymbol = loanAssetSymbol(loan.loanAssetContractAddress);
        svgParams.collateralContract = HexStrings.toHexString(uint160(loan.collateralContractAddress), 20);
        svgParams.collateralContractPartial = HexStrings.partialHexString(uint160(loan.collateralContractAddress), 10, 40);
        svgParams.collateralAssetSymbol = collateralAssetSymbol(loan.collateralContractAddress);
        svgParams.collateralId = Strings.toString(loan.collateralTokenId);
        svgParams.loanAmount = loanAmountString(loan.loanAmount, loan.loanAssetContractAddress);
        svgParams.interestAccrued = accruedInterest(nftLoanFacilitator, id, loan.loanAssetContractAddress);
        svgParams.durationDays = Strings.toString(loan.durationSeconds / (24 * 60 * 60));
        svgParams.endDateTime = loan.lastAccumulatedTimestamp == 0 ? "n/a" 
        : endDateTime(loan.lastAccumulatedTimestamp + loan.durationSeconds);
        
        return svgParams;
    }

    function interestRateString(INFTLoanFacilitator nftLoanFacilitator, uint256 perAnnumInterestRate) 
        private 
        view 
        returns (string memory)
    {
        return UintStrings.decimalString(
            perAnnumInterestRate,
            nftLoanFacilitator.INTEREST_RATE_DECIMALS() - 2,
            true
            );
    }

    function loanAmountString(uint256 amount, address asset) private view returns (string memory) {
        return UintStrings.decimalString(amount, IERC20Metadata(asset).decimals(), false);
    }

    function loanAssetSymbol(address asset) private view returns (string memory) {
        return IERC20Metadata(asset).symbol();
    }

    function collateralAssetSymbol(address asset) private view returns (string memory) {
        return ERC721(asset).symbol();
    }

    function accruedInterest(INFTLoanFacilitator nftLoanFacilitator, uint256 loanId, address loanAsset) 
        private 
        view 
        returns (string memory)
    {
        return UintStrings.decimalString(
            nftLoanFacilitator.interestOwed(loanId),
            IERC20Metadata(loanAsset).decimals(),
            false);
    }

    function loanStatus(uint256 lastAccumulatedTimestamp, uint256 durationSeconds, bool closed) 
        view 
        private 
        returns (string memory)
    {
        if (lastAccumulatedTimestamp == 0) return "awaiting lender";

        if (closed) return "closed";

        if (block.timestamp > (lastAccumulatedTimestamp + durationSeconds)) return "past due";

        return "accruing interest";
    }

    /** 
     * @param endDateSeconds The unix seconds timestamp of the loan end date
     * @return a string representation of the UTC end date and time of the loan,
     * in format YYYY-MM-DD HH:MM:SS
     */
    function endDateTime(uint256 endDateSeconds) private pure returns (string memory) {
        (uint year, uint month, 
        uint day, uint hour, 
        uint minute, uint second) = BokkyPooBahsDateTimeLibrary.timestampToDateTime(endDateSeconds);
        return string.concat(
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
        );
    } 
}