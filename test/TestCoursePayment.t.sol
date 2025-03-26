// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {CoursePayment} from "../src/CoursePayment.sol";
import {FeeReceiver} from "../src/FeeReceiver.sol";
import {ERC20PermitMock} from "./mocks/ERC20PermitMock.sol";

contract TestCoursePayment is Test {
    CoursePayment coursePayment;
    FeeReceiver feeReceiver;
    ERC20PermitMock usdc;

    address owner = makeAddr("OWNER");
    address alice;
    uint256 alicePk;

    uint256 constant USDC_INIT_AMOUNT = 100e6;
    uint256 constant COURSE_PRICE = 10e6;
    string constant COURSE_ID = "COURSE_1";
    bytes32 merkleRoot = 0x9d9f0b2ba62c368c3cff46340864572acfa5fb5c5ccf677fb1bbf1e63a711c1a;
    bytes32 proofOne = 0x618e9b9c521c79509a329f178099830d523c9f02250df11c735f40f087a17a13;
    bytes32 proofTwo = 0x2f1358a1621c600782137b80914d14703bcc017e163d9c75e885e65778d6ccc3;
    bytes32[] proof = [proofOne, proofTwo];

    uint256 amountToCollect = (25 * 1e6); // 25.000000
    uint256 amountToSend = amountToCollect * 4;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("user");
        console.log("alice", alice);
        feeReceiver = new FeeReceiver(owner);
        coursePayment = new CoursePayment(owner, address(feeReceiver));
        usdc = new ERC20PermitMock("USDC", "USDC");

        usdc.mint(owner, USDC_INIT_AMOUNT);
        usdc.mint(alice, USDC_INIT_AMOUNT);
        usdc.mint(address(coursePayment), amountToSend);

        vm.prank(owner);
        coursePayment.addAllowedToken(address(usdc));
    }

    function test_setUp() public view {
        assertEq(usdc.balanceOf(owner), USDC_INIT_AMOUNT);
        assertEq(usdc.balanceOf(alice), USDC_INIT_AMOUNT);
        assertEq(usdc.balanceOf(address(feeReceiver)), 0);
        assertEq(coursePayment.isPaid(alice, COURSE_ID), false);
    }

    function test_can_payWithPermit() public {
        uint256 amount = 10e6; // 10 USDC
        uint256 fee = 5e5; // 0.5 USDC fee
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v, bytes32 r, bytes32 s) = signMessageForPay(alicePk, alice, amount + fee, deadline);

        vm.prank(owner); // Only owner can call payWithPermit
        coursePayment.payWithPermit(address(usdc), alice, COURSE_ID, merkleRoot, amount, fee, deadline, v, r, s);

        CoursePayment.PaymentInfor memory paymentInfo = coursePayment.getPaymentInfo(0);
        assertEq(paymentInfo.token, address(usdc));
        assertEq(paymentInfo.amount, amount);
        assertEq(paymentInfo.fee, fee);
        assertEq(paymentInfo.paymentReceiverRoot, merkleRoot);

        // Check the results
        assertEq(usdc.balanceOf(alice), USDC_INIT_AMOUNT - amount - fee);
        assertEq(usdc.balanceOf(address(feeReceiver)), fee); // feeReceiver receives fee
        assertEq(coursePayment.isPaid(alice, COURSE_ID), true); // Mark as paid for the course
        assertEq(coursePayment.getCurrentPaymentId(), 1);
    }

    function test_can_claimPayment() public {
        uint256 amount = 10e6; // 10 USDC
        uint256 fee = 5e5; // 0.5 USDC fee
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 vPay, bytes32 rPay, bytes32 sPay) = signMessageForPay(alicePk, alice, amount + fee, deadline);

        vm.prank(owner); // Only owner can call payWithPermit
        coursePayment.payWithPermit(
            address(usdc), alice, COURSE_ID, merkleRoot, amount, fee, deadline, vPay, rPay, sPay
        );

        vm.startPrank(alice);
        (uint8 vClaim, bytes32 rClaim, bytes32 sClaim) = signMessageForClaim(alicePk, alice);
        vm.stopPrank();

        vm.prank(owner);
        coursePayment.claimPayment(0, proof, alice, amountToCollect, vClaim, rClaim, sClaim);
    }

    function signMessageForPay(uint256 privKey, address account, uint256 amount, uint256 deadline)
        public
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        // Create permit hash
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                account,
                address(coursePayment),
                amount, // Total amount to approve = amount + fee
                usdc.nonces(account),
                deadline
            )
        );

        bytes32 hash = usdc.DOMAIN_SEPARATOR().length > 0
            ? keccak256(abi.encodePacked("\x19\x01", usdc.DOMAIN_SEPARATOR(), structHash))
            : keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", structHash));

        // Alice signs the permit hash
        (v, r, s) = vm.sign(privKey, hash);
    }

    function signMessageForClaim(uint256 privKey, address account)
        public
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 hashedMessage = coursePayment.getMessageHash(account, amountToCollect);
        (v, r, s) = vm.sign(privKey, hashedMessage);
    }
}
