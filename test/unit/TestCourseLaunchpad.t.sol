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
    address backer_1 = makeAddr("backer_1");
    address backer_2 = makeAddr("backer_2");
    address backer_3 = makeAddr("backer_3");
    address backer_4 = makeAddr("backer_4");

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

        address[6] memory backers = [launchpadOwner, backer, backer_1, backer_2, backer_3, backer_4];

        for (uint256 i = 0; i < backers.length; i++) {
            vm.deal(backers[i], INIT_NATIVE_BALANCE);
            if (backers[i] != launchpadOwner) {
                token.mint(backers[i], INIT_TOKEN_BALANCE);
            }
        }

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

        address[2] memory backers = [backer, backer_1];
        uint256[2] memory amounts = [TOKEN_MIN_PLEDGE, TOKEN_MIN_PLEDGE * 2];

        for (uint256 i = 0; i < backers.length; i++) {
            vm.prank(backers[i]);
            token.approve(address(courseLaunchpad), amounts[i]);

            vm.prank(backers[i]);
            courseLaunchpad.pledgeERC20(LAUNCHPAD_ERC20, amounts[i]);

            uint256 balance = courseLaunchpad.getBackerBalance(LAUNCHPAD_ERC20, backers[i]);
            assertEq(balance, amounts[i]);
        }

        ICourseLaunchpad.Launchpad memory lp = courseLaunchpad.getLaunchpad(LAUNCHPAD_ERC20);
        assertEq(lp.totalPledged, TOKEN_MIN_PLEDGE * 3);
        assertEq(lp.token, address(token));
    }

    // ======= ERC20 Check EndFundingResult =======

    // check_end_funding_to_refunding
    function test_not_claim_refund_erc20_result_to_refunding() public {
        _initTokenLaunchpad();
        _approveLaunchpad(LAUNCHPAD_ERC20);
        _startFunding(LAUNCHPAD_ERC20);

        // Backer approve & pledge
        vm.prank(backer);
        token.approve(address(courseLaunchpad), TOKEN_MIN_PLEDGE);

        vm.prank(backer);
        courseLaunchpad.pledgeERC20(LAUNCHPAD_ERC20, TOKEN_MIN_PLEDGE);

        // check status pledge
        uint256 balance = courseLaunchpad.getBackerBalance(LAUNCHPAD_ERC20, backer);
        assertEq(balance, TOKEN_MIN_PLEDGE);

        ICourseLaunchpad.Launchpad memory lp = courseLaunchpad.getLaunchpad(LAUNCHPAD_ERC20);

        assertEq(lp.totalPledged, TOKEN_MIN_PLEDGE);
        assertEq(lp.token, address(token));

        // after 30 days
        vm.warp(block.timestamp + 30 days);

        // Admin check end funding
        vm.prank(owner);
        courseLaunchpad.endFundingResult(LAUNCHPAD_ERC20);

        // check status funding to REFUNDING
        ICourseLaunchpad.Launchpad memory lp_new = courseLaunchpad.getLaunchpad(LAUNCHPAD_ERC20);
        assertEq(uint256(lp_new.status), uint256(ICourseLaunchpad.LaunchpadStatus.REFUNDING));
    }

    // check_end_funding_to_waiting
    function test_not_claim_refund_erc20_result_to_waiting() public {
         _initTokenLaunchpad();
        _approveLaunchpad(LAUNCHPAD_ERC20);
        _startFunding(LAUNCHPAD_ERC20);

        address[4] memory backers = [backer, backer_1, backer_2, backer_3];
        uint256[4] memory amounts = [TOKEN_MIN_PLEDGE * 2, TOKEN_MIN_PLEDGE * 2, TOKEN_MIN_PLEDGE * 2, TOKEN_MIN_PLEDGE * 2];

        for (uint256 i = 0; i < backers.length; i++) {
            vm.prank(backers[i]);
            token.approve(address(courseLaunchpad), amounts[i]);

            vm.prank(backers[i]);
            courseLaunchpad.pledgeERC20(LAUNCHPAD_ERC20, amounts[i]);
        }

        ICourseLaunchpad.Launchpad memory lp = courseLaunchpad.getLaunchpad(LAUNCHPAD_ERC20);

        assertEq(lp.totalPledged, TOKEN_MIN_PLEDGE * 8);
        assertEq(lp.token, address(token));

        // after 30 days
        vm.warp(block.timestamp + 30 days);

        // Admin check end funding
        vm.prank(owner);
        courseLaunchpad.endFundingResult(LAUNCHPAD_ERC20);

        // Check status funding to WAITING
        ICourseLaunchpad.Launchpad memory lp_new = courseLaunchpad.getLaunchpad(LAUNCHPAD_ERC20);
        assertEq(uint256(lp_new.status), uint256(ICourseLaunchpad.LaunchpadStatus.WAITING));
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
