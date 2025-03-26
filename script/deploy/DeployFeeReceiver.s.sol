// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {FeeReceiver} from "../../src/FeeReceiver.sol";

contract DeployFeeReceiver is Script {
    address initialOwner = vm.envAddress("OWNER_ADDRESS");

    function run() external {
        vm.startBroadcast();
        new FeeReceiver(initialOwner);
        vm.stopBroadcast();
    }
}
