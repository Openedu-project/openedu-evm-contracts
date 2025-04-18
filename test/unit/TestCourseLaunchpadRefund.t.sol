// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.26;

// import {Test, console} from "forge-std/Test.sol";
// import {CourseLaunchpadRefund} from "../../src/CourseLaunchpadRefund.sol";
// import {ERC20PermitMock} from "../mocks/ERC20PermitMock.sol";

// contract TestCourseLaunchpadRefund is Test {
//     CourseLaunchpadRefund public refund;
//     ERC20PermitMock public token;

//     address owner = makeAddr("owner");
//     address user;
//     uint256 userPk;

//     bytes32 merkleRoot = 0x9d9f0b2ba62c368c3cff46340864572acfa5fb5c5ccf677fb1bbf1e63a711c1a;
//     bytes32 proofOne = 0x618e9b9c521c79509a329f178099830d523c9f02250df11c735f40f087a17a13;
//     bytes32 proofTwo = 0x2f1358a1621c600782137b80914d14703bcc017e163d9c75e885e65778d6ccc3;
//     bytes32[] proof = [proofOne, proofTwo];
//     uint256 amountToCollect = 25e6;
//     string launchpadId = "1";

//     function setUp() public {
//         (user, userPk) = makeAddrAndKey("user");

//         token = new ERC20PermitMock("Token", "USDC");
//         refund = new CourseLaunchpadRefund(address(0));

//         token.mint(owner, 100e6);

//         console.log("user", user);
//     }

//     function test_createRefund() public {
//         vm.startPrank(owner);
//         token.approve(address(refund), 100e6);
//         refund.createRefund(launchpadId, address(token), 100e6, merkleRoot);
//         vm.stopPrank();

//         assertEq(refund.getRefundInfo(launchpadId).token, address(token));
//         assertEq(refund.getRefundInfo(launchpadId).amount, 100e6);
//         assertEq(refund.getRefundInfo(launchpadId).receiversRoot, merkleRoot);
//     }

//     function test_claimRefund() public {
//         vm.startPrank(owner);
//         token.approve(address(refund), 100e6);
//         refund.createRefund(launchpadId, address(token), 100e6, merkleRoot);
//         vm.stopPrank();

//         vm.prank(user);
//         (uint8 v, bytes32 r, bytes32 s) = signMessageForClaim(userPk, user);

//         vm.prank(owner);
//         refund.claimRefund(launchpadId, user, amountToCollect, proof, v, r, s);

//         assertEq(token.balanceOf(user), amountToCollect);
//         assertEq(token.balanceOf(address(refund)), 75e6);
//         assertEq(refund.isClaimed(launchpadId, user), true);
//     }

//     function signMessageForClaim(uint256 privKey, address account)
//         public
//         view
//         returns (uint8 v, bytes32 r, bytes32 s)
//     {
//         bytes32 hashedMessage = refund.getMessageHash(account, amountToCollect);
//         (v, r, s) = vm.sign(privKey, hashedMessage);
//     }
// }
