// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {CourseLaunchpad} from "../../src/CourseLaunchpad.sol";

contract DeployCourseLaunchpad is Script {
    address initialOwner = vm.envAddress("OWNER_ADDRESS");

    function run() external {
        vm.startBroadcast();
        new CourseLaunchpad(initialOwner);
        vm.stopBroadcast();
    }
}
