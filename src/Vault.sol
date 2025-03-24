// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vault is Ownable2Step {
    error Vault__NoBalanceToWithdraw();

    constructor(address _initialOwner) Ownable(_initialOwner) {}

    event TokenWithdrawn(address token, uint256 amount);

    function withdrawAll(address token) public onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance == 0) revert Vault__NoBalanceToWithdraw();

        IERC20(token).transfer(msg.sender, balance);
        emit TokenWithdrawn(token, balance);
    }
}
