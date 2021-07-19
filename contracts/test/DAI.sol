pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DAI is ERC20 {
    constructor() ERC20("", "DAI") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}
