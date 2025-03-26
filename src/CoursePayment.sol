// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FeeReceiver} from "./FeeReceiver.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract CoursePayment is Ownable2Step, ReentrancyGuard, EIP712 {
    /*//////////////////////////////////////////////////////////////
                                  TYPE
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CoursePayment__TokenNotAllowed();
    error CoursePayment__AlreadyPaid();
    error CoursePayment__InvalidProof();
    error CoursePayment__AlreadyClaimed();
    error CoursePayment__InvalidSignature();
    error CoursePayment__InvalidPaymentId();
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    FeeReceiver private immutable i_feeReceiver;

    // define the message hash struct
    struct PaymentClaim {
        address account;
        uint256 amount;
    }

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("PaymentClaim(address account,uint256 amount)");

    mapping(address user => mapping(string courseId => bool isPaid)) private s_isUserPaid;
    mapping(address token => bool isAllowed) private s_allowedTokens;

    struct PaymentInfor {
        address token;
        string courseId;
        uint256 amount;
        uint256 fee;
        bytes32 paymentReceiverRoot;
    }

    mapping(uint256 paymentId => PaymentInfor paymentInfo) private s_paymentInfo;
    uint256 private s_paymentId;
    mapping(uint256 paymentId => mapping(address account => bool isClaimed)) private s_isPaymentClaimed;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTORS
    //////////////////////////////////////////////////////////////*/
    constructor(address initialOwner, address feeReceiver) Ownable(initialOwner) EIP712("Course Payment", "1.0.0") {
        i_feeReceiver = FeeReceiver(feeReceiver);
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CoursePaid(address indexed user, string courseId);
    event CoursePaidWithPermit(address indexed user, string courseId);
    event PaymentClaimed(uint256 indexed paymentId, address indexed account, uint256 amount);
    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAllowedToken(address token) {
        if (!s_allowedTokens[token]) revert CoursePayment__TokenNotAllowed();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function addAllowedToken(address token) external onlyOwner {
        s_allowedTokens[token] = true;
    }

    function removeAllowedToken(address token) external onlyOwner {
        s_allowedTokens[token] = false;
    }

    /*//////////////////////////////////////////////////////////////
                            PAY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function payWithPermit(
        address token,
        address sender,
        string memory courseId,
        bytes32 paymentReceiverRoot,
        uint256 amount,
        uint256 fee,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyAllowedToken(token) onlyOwner {
        if (s_isUserPaid[sender][courseId]) revert CoursePayment__AlreadyPaid();

        IERC20Permit(token).permit(sender, address(this), amount + fee, deadline, v, r, s);
        IERC20(token).safeTransferFrom(sender, address(this), amount);
        IERC20(token).safeTransferFrom(sender, address(i_feeReceiver), fee);

        s_isUserPaid[sender][courseId] = true;
        s_paymentInfo[s_paymentId++] = PaymentInfor({
            token: token,
            courseId: courseId,
            amount: amount,
            fee: fee,
            paymentReceiverRoot: paymentReceiverRoot
        });

        emit CoursePaidWithPermit(sender, courseId);
    }

    /*//////////////////////////////////////////////////////////////
                      PAYMENT RECEIVERS FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function claimPayment(
        uint256 paymentId,
        bytes32[] memory proof,
        address account,
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        PaymentInfor memory paymentInfo = s_paymentInfo[paymentId];
        if (paymentInfo.token == address(0)) revert CoursePayment__InvalidPaymentId();

        if (s_isPaymentClaimed[paymentId][account]) revert CoursePayment__AlreadyClaimed();

        // Verify the signature
        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert CoursePayment__InvalidSignature();
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(proof, paymentInfo.paymentReceiverRoot, leaf)) {
            revert CoursePayment__InvalidProof();
        }

        s_isPaymentClaimed[paymentId][account] = true;

        emit PaymentClaimed(paymentId, account, amount);

        IERC20(paymentInfo.token).safeTransfer(account, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          SIGNATURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, PaymentClaim({account: account, amount: amount}))));
    }

    function _isValidSignature(address signer, bytes32 digest, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (bool)
    {
        // could also use SignatureChecker.isValidSignatureNow(signer, digest, signature)
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
    function isPaid(address user, string memory courseId) external view returns (bool) {
        return s_isUserPaid[user][courseId];
    }

    function getPaymentInfo(uint256 paymentId) external view returns (PaymentInfor memory) {
        return s_paymentInfo[paymentId];
    }

    function getCurrentPaymentId() external view returns (uint256) {
        return s_paymentId;
    }
}
