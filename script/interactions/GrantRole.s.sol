// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract GrantRole is Script {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address contractAddress = 0x1cc085A6b7c12167359D026fa044a18364380C89;
    address addressForGrant = 0xAc39d3aBEd258D4A329107776b31bdeF9C906E07;

    function run() public {
        vm.startBroadcast();
        AccessControl(contractAddress).grantRole(MINTER_ROLE, addressForGrant);
        vm.stopBroadcast();
    }
}
