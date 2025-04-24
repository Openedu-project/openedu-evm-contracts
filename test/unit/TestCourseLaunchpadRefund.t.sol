// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {CourseLaunchpad} from "../../src/CourseLaunchpad.sol";
import {CourseLaunchpadRefund} from "../../src/CourseLaunchpadRefund.sol";
import {ICourseLaunchpad} from "../../src/interfaces/ICourseLaunchpad.sol";
import {ERC20PermitMock} from "../mocks/ERC20PermitMock.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleHelper} from "../../src/utils/MerkleHelper.sol";

contract CourseLaunchpadPledgeTest is Test {
    using SafeERC20 for IERC20;

    CourseLaunchpad courseLaunchpad;
    CourseLaunchpadRefund courseLaunchpadRefund;
    ERC20PermitMock token;

    address owner;
    uint256 ownerPk;
    
    address launchpadOwner;
    uint256 launchpadOwnerPk;
    
    address backer;
    address backer_1;
    address backer_2;
    address backer_3;
    address backer_4;

    uint256 backerPk;
    uint256 backer_1Pk;
    uint256 backer_2Pk;
    uint256 backer_3Pk;
    uint256 backer_4Pk;

    string constant LAUNCHPAD_NATIVE = "native_launchpad";
    string constant LAUNCHPAD_ERC20 = "erc20_launchpad";

    uint256 constant INIT_NATIVE_BALANCE = 100 ether;
    uint256 constant NATIVE_GOAL = 10 ether;
    uint256 constant NATIVE_MIN_PLEDGE = 0.01 ether;

    uint256 constant INIT_TOKEN_BALANCE = 100_000e6;
    uint256 constant TOKEN_GOAL = 10_000e6;
    uint256 constant TOKEN_MIN_PLEDGE = 1_000e6;

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("owner");
        (launchpadOwner, launchpadOwnerPk) = makeAddrAndKey("creator");
        
        courseLaunchpad = new CourseLaunchpad(owner);
        token = new ERC20PermitMock("MockToken", "MTK");

        courseLaunchpadRefund = new CourseLaunchpadRefund(address(courseLaunchpad));

        // Lấy địa chỉ và private key của các backers
        (backer, backerPk) = makeAddrAndKey("backer");
        (backer_1, backer_1Pk) = makeAddrAndKey("backer_1");
        (backer_2, backer_2Pk) = makeAddrAndKey("backer_2");
        (backer_3, backer_3Pk) = makeAddrAndKey("backer_3");
        (backer_4, backer_4Pk) = makeAddrAndKey("backer_4");

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

    // ======= ERC20 Check Refund =======

    function test_multiple_backers_claim_refund_min_pledge() public {
        // === Setup launchpad ===
        _initTokenLaunchpad();
        _approveLaunchpad(LAUNCHPAD_ERC20);
        _startFunding(LAUNCHPAD_ERC20);

        // === Backers approve + pledge ===
        address[2] memory backersArray = [backer, backer_1];
        uint256[2] memory amounts = [TOKEN_MIN_PLEDGE, TOKEN_MIN_PLEDGE];

        // Convert backersArray and amounts to dynamic arrays
        address[] memory backersDynamic = new address[](2);
        uint256[] memory amountsDynamic = new uint256[](2);

        for (uint i = 0; i < 2; i++) {
            backersDynamic[i] = backersArray[i];
            amountsDynamic[i] = amounts[i];
        }

        for (uint i = 0; i < backersDynamic.length; i++) {
            vm.prank(backersDynamic[i]);
            token.approve(address(courseLaunchpad), TOKEN_MIN_PLEDGE);

            vm.prank(backersDynamic[i]);
            courseLaunchpad.pledgeERC20(LAUNCHPAD_ERC20, TOKEN_MIN_PLEDGE);

            assertEq(courseLaunchpad.getBackerBalance(LAUNCHPAD_ERC20, backersDynamic[i]), TOKEN_MIN_PLEDGE);
        }

        // === Giả lập hết thời gian funding và thất bại ===
        vm.warp(block.timestamp + 30 days);
        vm.prank(owner);
        courseLaunchpad.endFundingResult(LAUNCHPAD_ERC20);

        // === Backend tạo Merkle tree và chữ ký ===
        (bytes32 root, bytes32[] memory proof0) = MerkleHelper.createTreeAndProof(backersDynamic, amountsDynamic, 0);
        (, bytes32[] memory proof1) = MerkleHelper.createTreeAndProof(backersDynamic, amountsDynamic, 1);

        // === Ký thông điệp cho từng backer ===
        (uint8 v0, bytes32 r0, bytes32 s0) = signMessageForClaim(backerPk, backersDynamic[0], TOKEN_MIN_PLEDGE);
        (uint8 v1, bytes32 r1, bytes32 s1) = signMessageForClaim(backer_1Pk, backersDynamic[1], TOKEN_MIN_PLEDGE);

        // === Owner gọi refundLaunchpad ===
        vm.prank(owner);
        courseLaunchpad.refundLaunchpad(LAUNCHPAD_ERC20, address(courseLaunchpadRefund), root);

        // === Claim refund cho từng backer ===
        for (uint i = 0; i < backersDynamic.length; i++) {
            uint256 balanceBefore = token.balanceOf(backersDynamic[i]);
            bytes32[] memory proof = i == 0 ? proof0 : proof1;
            (uint8 v, bytes32 r, bytes32 s) = i == 0 ? (v0, r0, s0) : (v1, r1, s1);

            vm.prank(backersDynamic[i]);
            courseLaunchpadRefund.claimRefund(LAUNCHPAD_ERC20, backersDynamic[i], TOKEN_MIN_PLEDGE, proof, v, r, s);

            assertEq(token.balanceOf(backersDynamic[i]), balanceBefore + TOKEN_MIN_PLEDGE);
            assertTrue(courseLaunchpadRefund.isClaimed(LAUNCHPAD_ERC20, backersDynamic[i]));
        }
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

    function signMessageForClaim(uint256 privKey, address account, uint256 amount)
        public
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 hashedMessage = courseLaunchpadRefund.getMessageHash(account, amount);
        (v, r, s) = vm.sign(privKey, hashedMessage);
    }
}