pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DAI is ERC20 {
    constructor() ERC20("", "DAI") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }

    function mint(uint256 amount, address to) external {
        _mint(to, amount);
    }
}
