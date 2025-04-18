// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {CourseLaunchpadRefund} from "../../src/CourseLaunchpadRefund.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployCourseLaunchpadRefund is Script {
    address courseLaunchpad = DevOpsTools.get_most_recent_deployment("CourseLaunchpad", block.chainid);

    function run() external {
        vm.startBroadcast();
        new CourseLaunchpadRefund(courseLaunchpad);
        vm.stopBroadcast();
    }
}
