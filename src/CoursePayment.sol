// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Vault} from "./Vault.sol";
import {FeeReceiver} from "./FeeReceiver.sol";

contract CoursePayment is Ownable2Step, ReentrancyGuard, EIP712 {
    /*//////////////////////////////////////////////////////////////
                                  TYPE
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;

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
    Vault private s_vault;
    FeeReceiver private s_feeReceiver;

    // define the message hash struct
    struct PaymentClaim {
        address account;
        uint256 amount;
    }

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("PaymentClaim(address account,uint256 amount)");

    mapping(address user => mapping(string courseId => bool isPaid)) private s_isUserPaid;
    mapping(address token => bool isAllowed) private s_allowedTokens;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTORS
    //////////////////////////////////////////////////////////////*/
    constructor(address initialOwner, address vault, address feeReceiver)
        Ownable(initialOwner)
        EIP712("Course Payment", "1.0.0")
    {
        s_vault = Vault(vault);
        s_feeReceiver = FeeReceiver(feeReceiver);
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

    function changeVault(address newVault) external onlyOwner {
        s_vault = Vault(newVault);
    }

    function changeFeeReceiver(address newFeeReceiver) external onlyOwner {
        s_feeReceiver = FeeReceiver(newFeeReceiver);
    }

    /*//////////////////////////////////////////////////////////////
                            PAY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function payWithPermit(
        address token,
        address sender,
        string memory courseId,
        uint256 amount,
        uint256 fee,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyAllowedToken(token) onlyOwner {
        if (s_isUserPaid[sender][courseId]) revert CoursePayment__AlreadyPaid();

        IERC20Permit(token).permit(sender, address(this), amount + fee, deadline, v, r, s);
        IERC20(token).safeTransferFrom(sender, address(s_vault), amount);
        IERC20(token).safeTransferFrom(sender, address(s_feeReceiver), fee);

        s_isUserPaid[sender][courseId] = true;

        emit CoursePaidWithPermit(sender, courseId);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function isPaid(address user, string memory courseId) external view returns (bool) {
        return s_isUserPaid[user][courseId];
    }
}
