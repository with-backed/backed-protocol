//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


// This is the main building block for smart contracts.
contract DAI is ERC20 {

    constructor() public ERC20("", "DAI") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}
