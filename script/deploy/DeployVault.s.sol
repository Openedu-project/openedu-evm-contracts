// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../../src/Vault.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployVault is Script {
    address initialOwner = vm.envAddress("OWNER_ADDRESS");
    address feeReceiver = DevOpsTools.get_most_recent_deployment("FeeReceiver", block.chainid);

    function run() external {
        vm.startBroadcast();
        new Vault(initialOwner, feeReceiver);
        vm.stopBroadcast();
    }
}
