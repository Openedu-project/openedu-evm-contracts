// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {SponsorNFT} from "../../src/SponsorNFT.sol";

contract DeployBadge is Script {
    address initialOwner = vm.envAddress("OWNER_ADDRESS");

    function run() external {
        vm.startBroadcast();
        new SponsorNFT(initialOwner, "OpenEdu Badge", "OEB");
        vm.stopBroadcast();
    }
}
