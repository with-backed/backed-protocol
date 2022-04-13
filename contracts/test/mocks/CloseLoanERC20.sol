// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../../interfaces/INFTLoanFacilitator.sol";

contract CloseLoanERC20 is ERC20, IERC721Receiver {
    INFTLoanFacilitator nftLoanFacilitator;

    constructor(address facilitatorAddress) ERC20("MAL", "MAL") {
        nftLoanFacilitator = INFTLoanFacilitator(facilitatorAddress);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address,
        uint256
    ) internal virtual override {
        if (from == address(0)) return;
        nftLoanFacilitator.closeLoan(1, address(this));
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}