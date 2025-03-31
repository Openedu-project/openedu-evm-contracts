// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20PermitMock is ERC20Permit {
    constructor(string memory name, string memory symbol) ERC20Permit(name) ERC20(symbol, "1") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
