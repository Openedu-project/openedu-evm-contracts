// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICourseLaunchpadRefund {
    /*//////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/
    error CourseLaunchpadRefund__OnlyCourseLaunchpad();
    error CourseLaunchpadRefund__RefundNotCreated();
    error CourseLaunchpadRefund__AlreadyClaimed();
    error CourseLaunchpadRefund__InvalidSignature();
    error CourseLaunchpadRefund__InvalidProof();

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/
    event RefundCreated(string indexed launchpadId, address indexed token, uint256 amount, bytes32 receiversRoot);
    event RefundClaimed(string indexed launchpadId, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function createRefund(string memory launchpadId, address token, uint256 amount, bytes32 receiversRoot) external;

    function claimRefund(
        string memory launchpadId,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
