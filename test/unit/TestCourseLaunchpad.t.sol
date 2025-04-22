// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {CourseLaunchpad} from "../../src/CourseLaunchpad.sol";
import {ICourseLaunchpad} from "../../src/interfaces/ICourseLaunchpad.sol";
import {ERC20PermitMock} from "../mocks/ERC20PermitMock.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CourseLaunchpadPledgeTest is Test {
    using SafeERC20 for IERC20;

    CourseLaunchpad courseLaunchpad;
    ERC20PermitMock token;

    address owner = makeAddr("owner");
    address launchpadOwner = makeAddr("creator");
    address backer = makeAddr("backer");

    string constant LAUNCHPAD_NATIVE = "native_launchpad";
    string constant LAUNCHPAD_ERC20 = "erc20_launchpad";

    uint256 constant INIT_NATIVE_BALANCE = 100 ether;
    uint256 constant NATIVE_GOAL = 10 ether;
    uint256 constant NATIVE_MIN_PLEDGE = 0.01 ether;

    uint256 constant INIT_TOKEN_BALANCE = 100_000e6;
    uint256 constant TOKEN_GOAL = 10_000e6;
    uint256 constant TOKEN_MIN_PLEDGE = 1_000e6;

    function setUp() public {
        courseLaunchpad = new CourseLaunchpad(owner);
        token = new ERC20PermitMock("MockToken", "MTK");

        vm.deal(launchpadOwner, INIT_NATIVE_BALANCE);
        vm.deal(backer, INIT_NATIVE_BALANCE);
        token.mint(backer, INIT_TOKEN_BALANCE);

        vm.prank(owner);
        courseLaunchpad.addAcceptedToken(address(0)); // accept native

        vm.prank(owner);
        courseLaunchpad.addAcceptedToken(address(token)); // accept ERC20
    }

    // ======= Native Pledge =======
    function test_can_pledge_native() public {
        _initNativeLaunchpad();
        _approveLaunchpad(LAUNCHPAD_NATIVE);
        _startFunding(LAUNCHPAD_NATIVE);

        vm.prank(backer);
        courseLaunchpad.pledgeNative{value: NATIVE_MIN_PLEDGE}(LAUNCHPAD_NATIVE);

        uint256 balance = courseLaunchpad.getBackerBalance(LAUNCHPAD_NATIVE, backer);
        assertEq(balance, NATIVE_MIN_PLEDGE);

        ICourseLaunchpad.Launchpad memory lp = courseLaunchpad.getLaunchpad(LAUNCHPAD_NATIVE);
        assertEq(lp.totalPledged, NATIVE_MIN_PLEDGE);
        assertEq(lp.token, address(0));
    }

    // ======= ERC20 Pledge =======
    function test_can_pledge_erc20() public {
        _initTokenLaunchpad();
        _approveLaunchpad(LAUNCHPAD_ERC20);
        _startFunding(LAUNCHPAD_ERC20);

        vm.prank(backer);
        token.approve(address(courseLaunchpad), TOKEN_MIN_PLEDGE);

        vm.prank(backer);
        courseLaunchpad.pledgeERC20(LAUNCHPAD_ERC20, TOKEN_MIN_PLEDGE);

        uint256 balance = courseLaunchpad.getBackerBalance(LAUNCHPAD_ERC20, backer);
        assertEq(balance, TOKEN_MIN_PLEDGE);

        ICourseLaunchpad.Launchpad memory lp = courseLaunchpad.getLaunchpad(LAUNCHPAD_ERC20);
        assertEq(lp.totalPledged, TOKEN_MIN_PLEDGE);
        assertEq(lp.token, address(token));
    }

    // ======= Helpers =======

    function _initNativeLaunchpad() internal {
        vm.prank(launchpadOwner);
        courseLaunchpad.initLaunchpad{value: NATIVE_MIN_PLEDGE}(
            LAUNCHPAD_NATIVE, launchpadOwner, address(0), NATIVE_GOAL, NATIVE_MIN_PLEDGE
        );
    }

    function _initTokenLaunchpad() internal {
        vm.prank(launchpadOwner);
        courseLaunchpad.initLaunchpad{value: NATIVE_MIN_PLEDGE}(
            LAUNCHPAD_ERC20, launchpadOwner, address(token), TOKEN_GOAL, TOKEN_MIN_PLEDGE
        );
    }

    function _approveLaunchpad(string memory launchpadId) internal {
        vm.prank(owner);
        courseLaunchpad.approveLaunchpad(launchpadId);
    }

    function _startFunding(string memory launchpadId) internal {
        vm.prank(launchpadOwner);
        courseLaunchpad.startFunding(launchpadId, block.timestamp, block.timestamp + 1 days);
    }
}
