// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {ERC20PermitMock} from "test/mocks/ERC20PermitMock.sol";

contract DeployMockUSDC is Script {
    function run() public {
        vm.startBroadcast();
        new ERC20PermitMock("USDC", "USDC");
        vm.stopBroadcast();
    }
}
