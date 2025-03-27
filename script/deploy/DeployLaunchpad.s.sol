// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol"; 
import {Launchpad} from "../../src/Launchpad.sol";

contract LaunchpadScript is Script {
    Launchpad public launchpad;

    // Các tham số có thể cấu hình
    uint256 public constant MIN_STAKING = 0.00001 ether;
    uint8 public constant REFUND_PERCENT = 10;

    function setUp() public {}

    function run() public {
        // Lấy thông tin từ environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER_ADDRESS");
        
        // Log thông tin trước khi deploy
        console2.log("Deploying Launchpad with parameters:");
        console2.log("Owner:", owner);
        console2.log("Min Staking:", MIN_STAKING);
        console2.log("Refund Percent:", REFUND_PERCENT);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contract
        launchpad = new Launchpad(
            owner,
            MIN_STAKING,
            REFUND_PERCENT
        );

        vm.stopBroadcast();

        // Log kết quả
        console2.log("Launchpad deployed to:", address(launchpad));
        console2.log("Deployment completed successfully");
    }
}