pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/INFTLoanFacilitator.sol";

struct LendValues {
    uint256 loanAmount;
    uint256 perSecondInterestRate;
    uint256 durationSeconds;
}

interface ILendValuesSource {
    function lendValues(uint256 tokenId, address erc721ContractAddress, address loanAssetAddress) 
    external returns(LendValues memory);
}


contract LendVault is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable loanAsset;
    INFTLoanFacilitator public immutable facilitator;
    ILendValuesSource public lendValuesSource;

    constructor(IERC20 _loanAsset, INFTLoanFacilitator _facilitator, ILendValuesSource _lendValuesSource) ERC20("Lend Vault 1", "LV1") {
        loanAsset = _loanAsset;
        facilitator = _facilitator;
        lendValuesSource = _lendValuesSource;
    }

    function lend(uint256 loanId) external {
        (,,,,,,
        uint256 collateralTokenId,
        address collateralContractAddress,
        address loanAssetContractAddress) = facilitator.loanInfo(loanId);
        require(loanAssetContractAddress == address(loanAsset), 'wrong loan asset');

        // call to a contract which determines what values to use for lend. 
        // Multiple vaults could share a lendValuesSource contract, which is maybe thought to be good at evaluating asset worth.
        // We could even make `lendValues` a payable method so people could pay for valuations
        LendValues memory lendValues = lendValuesSource.lendValues(collateralTokenId, collateralContractAddress, loanAssetContractAddress);
        facilitator.underwriteLoan(loanId, lendValues.perSecondInterestRate, lendValues.loanAmount, lendValues.durationSeconds, address(this));
    }

    function seizeCollateral(uint256 loanId) external {
        facilitator.seizeCollateral(loanId, address(this));
    }

    function auction(uint256 tokenId, address tokenContract) external {
        // sell a seized asset
        // use Zora auction house
    }

    // close to https://github.com/pooltogether/pods-v3-contracts/blob/master/contracts/Pod.sol#L215
    function deposit(address to, uint256 amount) external returns (uint256){
        require(amount > 0, "invalid-amount");

        uint256 shares = _calculateAllocation(amount);

        _mint(to, shares);
        
        loanAsset.safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        
        // Return Shares Minted
        return shares;
    }

    function withdraw(address to, uint256 shares) external {
        uint256 amount = _calculateUnderlyingTokens(shares);

        _burn(msg.sender, shares);

        loanAsset.safeTransfer(msg.sender, amount);
    }

    // from https://github.com/pooltogether/pods-v3-contracts/blob/master/contracts/Pod.sol#L485
    function _calculateAllocation(uint256 amount) internal returns (uint256) {
        uint256 allocation = 0;
        uint256 _totalSupply = totalSupply();

        // Calculate Allocation
        if (_totalSupply == 0) {
            allocation = amount;
        } else {
            allocation = (amount * _totalSupply) / balance();
        }

        // Return Allocation Amount
        return allocation;
    }

    // close to https://github.com/pooltogether/pods-v3-contracts/blob/master/contracts/Pod.sol#L591
    function _calculateUnderlyingTokens(uint256 shares)
        internal
        view
        returns (uint256)
    {
        return (balance() * shares) / totalSupply();
    }

    function balance() public view returns (uint256) {
        loanAsset.balanceOf(address(this));
    }

}