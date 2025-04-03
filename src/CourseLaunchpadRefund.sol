// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ICourseLaunchpadRefund} from "./interfaces/ICourseLaunchpadRefund.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract CourseLaunchpadRefund is ICourseLaunchpadRefund, EIP712 {
    /*//////////////////////////////////////////////////////////////
                                  TYPE
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    struct PaymentClaim {
        address account;
        uint256 amount;
    }

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("PaymentClaim(address account,uint256 amount)");

    struct RefundInfo {
        address token;
        uint256 amount;
        bytes32 receiversRoot;
    }

    mapping(string => RefundInfo) private s_refundInfo;
    mapping(string => mapping(address => bool)) private s_isClaimed;
    address public immutable i_courseLaunchpad;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address courseLaunchpad) EIP712("Course Launchpad Refund", "1.0.0") {
        i_courseLaunchpad = courseLaunchpad;
    }

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function createRefund(string memory launchpadId, address token, uint256 amount, bytes32 receiversRoot) external {
        if (msg.sender != i_courseLaunchpad) revert CourseLaunchpadRefund__OnlyCourseLaunchpad();

        IERC20(token).safeTransferFrom(i_courseLaunchpad, address(this), amount);

        s_refundInfo[launchpadId] = RefundInfo({token: token, amount: amount, receiversRoot: receiversRoot});

        emit RefundCreated(launchpadId, token, amount, receiversRoot);
    }

    function claimRefund(
        string memory launchpadId,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (s_refundInfo[launchpadId].token == address(0)) revert CourseLaunchpadRefund__RefundNotCreated();

        if (s_isClaimed[launchpadId][account]) revert CourseLaunchpadRefund__AlreadyClaimed();

        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert CourseLaunchpadRefund__InvalidSignature();
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, s_refundInfo[launchpadId].receiversRoot, leaf)) {
            revert CourseLaunchpadRefund__InvalidProof();
        }

        s_isClaimed[launchpadId][account] = true;

        emit RefundClaimed(launchpadId, s_refundInfo[launchpadId].token, amount);

        IERC20(s_refundInfo[launchpadId].token).safeTransfer(account, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _isValidSignature(address signer, bytes32 digest, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (bool)
    {
        (
            address actualSigner,
            /*ECDSA.RecoverError recoverError*/
            ,
            /*bytes32 signatureLength*/
        ) = ECDSA.tryRecover(digest, _v, _r, _s);
        return (actualSigner == signer);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getRefundInfo(string memory launchpadId) public view returns (RefundInfo memory) {
        return s_refundInfo[launchpadId];
    }

    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, PaymentClaim({account: account, amount: amount}))));
    }

    function isClaimed(string memory launchpadId, address account) public view returns (bool) {
        return s_isClaimed[launchpadId][account];
    }
}
