// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FeeReceiver} from "./FeeReceiver.sol";

contract Vault is Ownable2Step {
    using SafeERC20 for IERC20;

    error Vault__NoBalanceToWithdraw();

    address private s_feeReceiver;

    constructor(address _initialOwner, address _feeReceiver) Ownable(_initialOwner) {
        s_feeReceiver = _feeReceiver;
    }

    event TokenWithdrawn(address token, address indexed receiver, uint256 amount);

    function withdraw(address token, uint256 amount, uint256 fee, address to) public onlyOwner {
        if (amount + fee > IERC20(token).balanceOf(address(this))) revert Vault__NoBalanceToWithdraw();

        IERC20(token).safeTransfer(to, amount);
        if (fee > 0) {
            IERC20(token).safeTransfer(s_feeReceiver, fee);
        }
        emit TokenWithdrawn(token, to, amount);
    }
}
