// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Vault} from "./Vault.sol";

contract FeeReceiver is Ownable2Step {
    using SafeERC20 for IERC20;

    error FeeReceiver__NoBalanceToWithdraw();

    constructor(address _initialOwner) Ownable(_initialOwner) {}

    event TokenWithdrawnAll(address receiver, uint256 amount);

    function withdrawAll(address token, address to) public onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance == 0) revert FeeReceiver__NoBalanceToWithdraw();

        IERC20(token).safeTransfer(to, balance);
        emit TokenWithdrawnAll(to, balance);
    }
}
