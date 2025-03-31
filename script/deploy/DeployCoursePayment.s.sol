// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {CoursePayment} from "../../src/CoursePayment.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployCoursePayment is Script {
    address initialOwner = vm.envAddress("OWNER_ADDRESS");
    address vault = DevOpsTools.get_most_recent_deployment("Vault", block.chainid);
    address feeReceiver = DevOpsTools.get_most_recent_deployment("FeeReceiver", block.chainid);

    function run() external {
        vm.startBroadcast();
        new CoursePayment(initialOwner, vault, feeReceiver);
        vm.stopBroadcast();
    }
}
