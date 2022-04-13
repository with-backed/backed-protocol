// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract FeeOnTransferERC20 is ERC20("FEE", "FEE", 18) {
    uint256 public feeBips = 200;

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        uint256 amountAfterFee;
        unchecked {
            amountAfterFee = amount - (amount * feeBips / 10_000);
            balanceOf[to] += amountAfterFee;
        }

        emit Transfer(from, to, amountAfterFee);

        return true;
    }
}