// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {CourseLaunchpad} from "../../src/CourseLaunchpad.sol";
import {ICourseLaunchpad} from "../../src/interfaces/ICourseLaunchpad.sol";

contract TestCourseLaunchpad is Test {
    CourseLaunchpad courseLaunchpad;
    address owner = makeAddr("owner");
    address launchpadOwner = makeAddr("launchpadOwner");
    string launchpadId = "launchpadId";
    uint256 INIT_ETHER_BALANCE = 100 ether;
    uint256 constant NATIVE_LAUNCHPAD_GOAL = 100e18;
    uint256 constant NATIVE_LAUNCHPAD_MIN_PLEDGE_AMOUNT = 1e16; // 0.01 ETH

    function setUp() public {
        courseLaunchpad = new CourseLaunchpad(owner);

        vm.deal(launchpadOwner, INIT_ETHER_BALANCE);
    }

    function test_can_initLaunchpad() public {
        _initNativeLaunchpad();

        ICourseLaunchpad.Launchpad memory launchpad = courseLaunchpad.getLaunchpad(launchpadId);
        assertEq(launchpad.owner, launchpadOwner);
        assertEq(launchpad.goal, NATIVE_LAUNCHPAD_GOAL);
        assertEq(launchpad.minPledgeAmount, NATIVE_LAUNCHPAD_MIN_PLEDGE_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(ICourseLaunchpad.LaunchpadAlreadyExists.selector, launchpadId));
        _initNativeLaunchpad();
    }

    function test_can_pledgeNative() public {
        _initNativeLaunchpad();
        _approveLaunchpad();
        _startFunding();

        vm.prank(launchpadOwner);
        courseLaunchpad.pledgeNative{value: NATIVE_LAUNCHPAD_MIN_PLEDGE_AMOUNT}(launchpadId);

        ICourseLaunchpad.Launchpad memory launchpad = courseLaunchpad.getLaunchpad(launchpadId);
        ICourseLaunchpad.LaunchpadStatus status = ICourseLaunchpad.LaunchpadStatus.FUNDING;
        uint256 backerBalance = courseLaunchpad.getBackerBalance(launchpadId, launchpadOwner);

        assertEq(backerBalance, NATIVE_LAUNCHPAD_MIN_PLEDGE_AMOUNT);
        assertEq(uint256(launchpad.status), uint256(status));
        assertEq(launchpad.startFundingTime, block.timestamp);
        assertEq(launchpad.endFundingTime, block.timestamp + 1 days);
        assertEq(launchpad.totalPledged, NATIVE_LAUNCHPAD_MIN_PLEDGE_AMOUNT);
        assertEq(address(courseLaunchpad).balance, NATIVE_LAUNCHPAD_MIN_PLEDGE_AMOUNT + 0.01 ether);
    }

    function _initNativeLaunchpad() internal {
        vm.prank(launchpadOwner);
        courseLaunchpad.initLaunchpad{value: NATIVE_LAUNCHPAD_MIN_PLEDGE_AMOUNT}(
            launchpadId, launchpadOwner, address(0), NATIVE_LAUNCHPAD_GOAL, NATIVE_LAUNCHPAD_MIN_PLEDGE_AMOUNT
        );
    }

    function _approveLaunchpad() internal {
        vm.prank(owner);
        courseLaunchpad.approveLaunchpad(launchpadId);
    }

    function _startFunding() internal {
        vm.prank(launchpadOwner);
        courseLaunchpad.startFunding(launchpadId, block.timestamp, block.timestamp + 1 days);
    }
}
