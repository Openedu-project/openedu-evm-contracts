// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {SponsorNft} from "../../src/SponsorNft.sol";

contract DeployCertificate is Script {
    address initialOwner = vm.envAddress("OWNER_ADDRESS");

    function run() external {
        vm.startBroadcast();
        new SponsorNft(initialOwner, "OpenEdu Certificate", "OEC");
        vm.stopBroadcast();
    }
}
