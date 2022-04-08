pragma solidity 0.8.12;

interface INFTLendOfferFacilitator {
    /// See lendOfferInfo
    struct LendOffer {
        uint16 minInterestRate;
        uint32 maxDurationSeconds;
        address lender;
        address collateralContractAddress;
        address loanAssetContractAddress;
        uint128 maxLoanAmount;
        int256 collateralTokenId;
    }

    /**
     * @notice Emitted when the lend offer is created
     * @param id The id of the new lend offer
     * @param lender msg.sender
     * @param collateralContract The contract address of the collateral NFT
     * @param collateralTokenId The token id of the collateral NFT, can be a negative number to indicate lender doesn't care which token ID
     * @param loanAssetContract The contract address of the loan asset
     * @param minInterestRate The min per second interest rate, scaled by SCALAR
     * @param maxLoanAmount maximum loan amount
     * @param maxDurationSeconds maximum loan duration in seconds
     */
    event CreateLendOffer(
        uint256 indexed id,
        address indexed lender,
        address collateralContract,
        int256 collateralTokenId,
        address loanAssetContract,
        uint256 minInterestRate,
        uint256 maxLoanAmount,
        uint256 maxDurationSeconds
    );

    /**
     * @notice Creates on-chain lend offer representing users desire to lend against a particular NFT
     * @param collateralContractAddress The contract address of the collateral NFT
     * @param collateralTokenId The token id of the collateral NFT, can be a negative number to indicate lender doesn't care which token ID
     * @param loanAssetContractAddress The contract address of the loan asset
     * @param minInterestRate The min per second interest rate, scaled by SCALAR
     * @param maxLoanAmount maximum loan amount
     * @param maxDurationSeconds maximum loan duration in seconds
     * @return id of the created lend offer
     */
    function createLendOfferForNFT(
        address collateralContractAddress,
        int256 collateralTokenId,
        address loanAssetContractAddress,
        uint16 minInterestRate,
        uint128 maxLoanAmount,
        uint32 maxDurationSeconds
    ) external returns (uint256 id);

    /**
     * @notice Emitted when the loan is created
     * @param id The id of the lend offer
     * @param fulfiller address of user who fulfilled lend offer
     */
    event FulfillLendOffer(
        uint256 indexed id,
        address indexed fulfiller,
        uint256 loanId
    );

    /**
     * @notice Fulfills on-chain lend offer, approving facilitator to spend ERC20 to underwrite loan on behalf of initial lender
     * @param lendOfferId id of lend offer that the lender created
     @param loanId The loan from the facilitator that will be used to fulfill this lend offer
     */
    function fulfillLendOffer(uint256 lendOfferId, uint256 loanId) external;

    /**
     * @notice Fulfills on-chain lend offer, more gas efficient than fulfillLendOffer, since it assumes NFTLendOfferFacilitator has already approved ERC20 transfer from NFTLoanFacilitator
     * @param lendOfferId id of lend offer that the lender created
     * @param loanId The loan from the facilitator that will be used to fulfill this lend offer
     */
    function fulfillLendOfferWithNoApprovals(
        uint256 lendOfferId,
        uint256 loanId
    ) external;

    /**
     * @notice returns the info for this lend offer
     * @param id The id of the lend offer
     * @return minInterestRate The per second interest rate, scaled by SCALAR
     * @return maxDurationSeconds The loan duration in seconds
     * @return lender LendOfferder who initiated the lend offer
     * @return collateralContractAddress The contract address of the NFT collateral
     * @return loanAssetContractAddress The contract address of the loan asset.
     * @return maxLoanAmount The loan amount
     * @return collateralTokenId The token ID of the NFT collateral
     */
    function lendOfferInfo(uint256 id)
        external
        view
        returns (
            uint16 minInterestRate,
            uint32 maxDurationSeconds,
            address lender,
            address collateralContractAddress,
            address loanAssetContractAddress,
            uint128 maxLoanAmount,
            int256 collateralTokenId
        );

    /**
     * @notice returns the info for this lend offer
     * @dev convenience method for fetching struct rather than decomposed lend offer via lend offerInfo
     * @param id The id of the lend offer
     * @return LendOffer The lend offer corresponding to lend offer Id
     */
    function lendOfferInfoStruct(uint256 id)
        external
        view
        returns (LendOffer memory);

    /**
     * @notice deletes a lend offer, making it unable to be fulfilled
     * @param id The id of the lend offer
     */
    function cancelLendOffer(uint256 id) external;
}
