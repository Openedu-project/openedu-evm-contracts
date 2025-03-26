// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {CoursePayment} from "../../src/CoursePayment.sol";

contract DeployCoursePayment is Script {
    address initialOwner = vm.envAddress("OWNER_ADDRESS");

    function run() external {
        vm.startBroadcast();
        CoursePayment coursePayment = new CoursePayment(initialOwner, 0x2C96ac8a9E3b23e67f882F8E62669031466cD29b);
        coursePayment.addAllowedToken(0x7c20E41909C1Cbfc82dF5eE8B7cb7760d36BE0a2);
        vm.stopBroadcast();
    }
}
