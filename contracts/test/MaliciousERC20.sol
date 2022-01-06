pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/INFTLoanFacilitator.sol";

import "hardhat/console.sol";

contract MaliciousERC20 is ERC20 {
    INFTLoanFacilitator nftLoanFacilitator;

    constructor(address facilitatorAddress) ERC20("", "MAL") {
        nftLoanFacilitator = INFTLoanFacilitator(facilitatorAddress);
        _mint(msg.sender, 1000000 * (10**uint256(decimals())));
    }

    function mint(uint256 amount, address to) external {
        _mint(to, amount * (10**decimals()));
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        nftLoanFacilitator.closeLoan(1, address(this));
        return true;
    }
}
