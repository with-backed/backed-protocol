pragma solidity 0.8.12;

import "../interfaces/INFTLendOfferFacilitator.sol";
import {INFTLoanFacilitator} from "../interfaces/INFTLoanFacilitator.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeTransferLib, ERC20} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {INFTLoanFacilitator} from "../interfaces/INFTLoanFacilitator.sol";

contract NFTLendOfferFacilitator is INFTLendOfferFacilitator {
    using SafeTransferLib for ERC20;

    INFTLoanFacilitator facilitator;

    /// @dev tracks bid count
    uint256 private _nonce;

    /// See {INFTLendOfferFacilitator-lendOfferInfo}.
    mapping(uint256 => LendOffer) public lendOfferInfo;

    constructor(address _facilitator) {
        facilitator = INFTLoanFacilitator(_facilitator);
    }

    // ==== modifiers ====

    modifier lendOfferExists(uint256 lendOfferId) {
        require(
            lendOfferInfo[lendOfferId].lender != address(0),
            "NFTLendOfferFacilitator: lend offer does not exist"
        );
        _;
    }

    // === view ===

    /// See {INFTLendOfferFacilitator-lendOfferInfoStruct}.
    function lendOfferInfoStruct(uint256 lendOfferId)
        external
        view
        override
        returns (LendOffer memory)
    {
        return lendOfferInfo[lendOfferId];
    }

    // ==== state changing ====

    /// See {INFTLendOfferFacilitator-createLendOfferForNFT}.
    function createLendOfferForNFT(
        address collateralContractAddress,
        int256 collateralTokenId,
        address loanAssetContractAddress,
        uint16 minInterestRate,
        uint128 maxLoanAmount,
        uint32 maxDurationSeconds
    ) external override returns (uint256 id) {
        id = ++_nonce;
        LendOffer storage bid = lendOfferInfo[id];
        bid.lender = msg.sender;
        bid.collateralContractAddress = collateralContractAddress;
        bid.collateralTokenId = collateralTokenId;

        bid.minInterestRate = minInterestRate;
        bid.loanAssetContractAddress = loanAssetContractAddress;
        bid.maxLoanAmount = maxLoanAmount;
        bid.maxDurationSeconds = maxDurationSeconds;

        emit CreateLendOffer(
            id,
            msg.sender,
            collateralContractAddress,
            collateralTokenId,
            loanAssetContractAddress,
            minInterestRate,
            maxLoanAmount,
            maxDurationSeconds
        );
    }

    /// See {INFTLendOfferFacilitator-fulfillLendOffer}.
    function fulfillLendOffer(uint256 lendOfferId, uint256 loanId)
        external
        override
        lendOfferExists(lendOfferId)
    {
        _collateralAndLoanAssetMatch(lendOfferId, loanId);

        ERC20(lendOfferInfo[lendOfferId].loanAssetContractAddress).approve(
            address(facilitator),
            type(uint256).max
        );

        _fulfillLendOffer(lendOfferId, loanId);
    }

    /// See {INFTLendOfferFacilitator-fulfillLendOfferWithNoApprovals}.
    function fulfillLendOfferWithNoApprovals(
        uint256 lendOfferId,
        uint256 loanId
    ) external override lendOfferExists(lendOfferId) {
        _collateralAndLoanAssetMatch(lendOfferId, loanId);

        _fulfillLendOffer(lendOfferId, loanId);
    }

    function cancelLendOffer(uint256 id) external lendOfferExists(id) {
        require(
            msg.sender == lendOfferInfo[id].lender,
            "NFTLendOfferFacilitator: Only lender can cancel"
        );
        delete lendOfferInfo[id];
    }

    // === internal ===

    function _collateralAndLoanAssetMatch(uint256 lendOfferId, uint256 loanId)
        internal
        view
    {
        (
            ,
            ,
            ,
            ,
            address collateralAddressFromLoan,
            address loanAssetAddressFromLoan,
            ,
            ,
            uint256 tokenIdFromLoan
        ) = facilitator.loanInfo(loanId);

        LendOffer storage bid = lendOfferInfo[lendOfferId];

        require(
            bid.collateralTokenId < 0 ||
                tokenIdFromLoan == uint256(bid.collateralTokenId),
            "NFTLendOfferFacilitator: token ID mismatch"
        );
        require(
            bid.loanAssetContractAddress == loanAssetAddressFromLoan,
            "NFTLendOfferFacilitator: loan asset mismatch"
        );
        require(
            bid.collateralContractAddress == collateralAddressFromLoan,
            "NFTLendOfferFacilitator: collateral asset mismatch"
        );
    }

    function _fulfillLendOffer(uint256 lendOfferId, uint256 loanId) private {
        LendOffer memory bid = lendOfferInfo[lendOfferId];
        delete lendOfferInfo[lendOfferId];

        ERC20(bid.loanAssetContractAddress).safeTransferFrom(
            bid.lender,
            address(this),
            bid.maxLoanAmount
        );

        // lend on behalf of the lender
        facilitator.lend(
            loanId,
            bid.minInterestRate,
            bid.maxLoanAmount,
            bid.maxDurationSeconds,
            bid.lender
        );

        emit FulfillLendOffer(lendOfferId, msg.sender, loanId);
    }
}
