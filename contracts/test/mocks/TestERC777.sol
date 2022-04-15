// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract TestERC777 is ERC777("TEST", "Test Token", new address[](0)) {
    function mint(address to, uint256 amount) external {
        _mint(to, amount, "", "", false);
    }
}
