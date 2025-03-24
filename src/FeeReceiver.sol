// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Vault} from "./Vault.sol";

contract FeeReceiver is Vault {
    constructor(address initialOwner) Vault(initialOwner) {}
}
