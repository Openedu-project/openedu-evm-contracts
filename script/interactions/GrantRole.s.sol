// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract GrantRole is Script {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address contractAddress = 0xA278DF5A2E5B136916C2c62851A717C64d9E6cE3;
    address addressForGrant = 0xAc39d3aBEd258D4A329107776b31bdeF9C906E07;

    function run() public {
        vm.startBroadcast();
        AccessControl(contractAddress).grantRole(MINTER_ROLE, addressForGrant);
        vm.stopBroadcast();
    }
}
