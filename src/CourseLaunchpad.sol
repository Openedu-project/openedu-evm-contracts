// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ICourseLaunchpad} from "./interfaces/ICourseLaunchpad.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ICourseLaunchpadRefund} from "./interfaces/ICourseLaunchpadRefund.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CourseLaunchpad is ICourseLaunchpad, Ownable2Step {
    using SafeERC20 for IERC20;

    mapping(string launchpadId => Launchpad) private s_launchpads;
    mapping(string launchpadId => bool isExist) private s_launchpadExist;
    mapping(string launchpadId => mapping(address user => uint256 pledgeAmount)) private s_backerBalances;
    string[] private s_refundingLaunchpads;

    uint256 private s_requiredStakeAmount;
    uint256 private s_maxFundingBps; // max total funding percent in a launchpad
    uint256 private s_maxPledgeBps; // max pledge percent in a launchpad of a backer
    uint256 private s_requiredVotingBps; // required total funding percent in a launchpad for voting

    constructor(address initialOwner) Ownable(initialOwner) {
        s_requiredStakeAmount = 0.01 ether; // initial required stake amount, can change in the future
        s_maxFundingBps = 200000; // 200% = 200000 bps
        s_maxPledgeBps = 2000; // 20% = 2000 bps
        s_requiredVotingBps = 8000; // 80% = 8000 bps
    }

    modifier onlyLaunchpadOwner(string memory launchpadId) {
        if (s_launchpads[launchpadId].owner != msg.sender) {
            revert Unauthorized(msg.sender, "Not launchpad owner");
        }
        _;
    }

    modifier onlyFundingLaunchpad(string memory launchpadId) {
        Launchpad memory launchpad = s_launchpads[launchpadId];
        bool isFunding = launchpad.status == LaunchpadStatus.FUNDING;
        bool isStarted = block.timestamp >= launchpad.startFundingTime;
        bool isEnded = block.timestamp <= launchpad.endFundingTime;
        if (!isFunding || !isStarted || !isEnded) {
            revert InvalidStatus(launchpad.status, LaunchpadStatus.FUNDING);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                       CONTRACT SETTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setRequiredStakeAmount(uint256 requiredStakeAmount) external onlyOwner {
        s_requiredStakeAmount = requiredStakeAmount;
    }

    function setMaxFundingBps(uint256 maxFundingBps) external onlyOwner {
        s_maxFundingBps = maxFundingBps;
    }

    function setMaxPledgeBps(uint256 maxPledgeBps) external onlyOwner {
        s_maxPledgeBps = maxPledgeBps;
    }

    function setRequiredVotingBps(uint256 requiredVotingBps) external onlyOwner {
        s_requiredVotingBps = requiredVotingBps;
    }

    /*//////////////////////////////////////////////////////////////
                        STATUS CONTROL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function approveLaunchpad(string memory launchpadId) external onlyOwner {
        LaunchpadStatus currentStatus = s_launchpads[launchpadId].status;
        if (currentStatus != LaunchpadStatus.INIT) {
            revert InvalidStatus(currentStatus, LaunchpadStatus.INIT);
        }

        s_launchpads[launchpadId].status = LaunchpadStatus.APPROVED;
        emit LaunchpadStatusUpdated(launchpadId, LaunchpadStatus.INIT, LaunchpadStatus.APPROVED);
    }

    function rejectLaunchpad(string memory launchpadId) external onlyOwner {
        Launchpad memory launchpad = s_launchpads[launchpadId];
        LaunchpadStatus currentStatus = launchpad.status;

        if (currentStatus != LaunchpadStatus.INIT && currentStatus != LaunchpadStatus.APPROVED) {
            revert InvalidStatus(currentStatus, LaunchpadStatus.INIT);
        }

        s_launchpads[launchpadId].status = LaunchpadStatus.REJECTED;

        (bool success,) = payable(launchpad.owner).call{value: launchpad.stakeAmount}("");
        if (!success) revert TransactionFailed("Failed to return stake amount");

        emit LaunchpadStatusUpdated(launchpadId, currentStatus, LaunchpadStatus.REJECTED);
    }

    function cancelLaunchpad(string memory launchpadId) external onlyLaunchpadOwner(launchpadId) {
        Launchpad memory launchpad = s_launchpads[launchpadId];
        LaunchpadStatus currentStatus = launchpad.status;
        if (currentStatus != LaunchpadStatus.INIT) {
            revert InvalidStatus(currentStatus, LaunchpadStatus.INIT);
        }

        s_launchpads[launchpadId].status = LaunchpadStatus.CANCELLED;

        (bool success,) = payable(launchpad.owner).call{value: launchpad.stakeAmount}("");
        if (!success) revert TransactionFailed("Failed to return stake amount");

        emit LaunchpadStatusUpdated(launchpadId, currentStatus, LaunchpadStatus.CANCELLED);
    }

    function startFunding(string memory launchpadId, uint256 startFundingTime, uint256 endFundingTime)
        external
        onlyLaunchpadOwner(launchpadId)
    {
        Launchpad storage launchpad = s_launchpads[launchpadId];
        LaunchpadStatus currentStatus = launchpad.status;
        if (currentStatus != LaunchpadStatus.APPROVED) {
            revert InvalidStatus(currentStatus, LaunchpadStatus.APPROVED);
        }

        launchpad.status = LaunchpadStatus.FUNDING;
        launchpad.startFundingTime = startFundingTime;
        launchpad.endFundingTime = endFundingTime;

        emit LaunchpadStatusUpdated(launchpadId, currentStatus, LaunchpadStatus.FUNDING);
    }

    function endFundingResult(string memory launchpadId) external {
        Launchpad storage launchpad = s_launchpads[launchpadId];
        LaunchpadStatus currentStatus = launchpad.status;

        if (currentStatus != LaunchpadStatus.FUNDING) {
            revert InvalidStatus(currentStatus, LaunchpadStatus.FUNDING);
        }
        if (block.timestamp < launchpad.endFundingTime) {
            revert TransactionFailed("Funding period not ended");
        }

        LaunchpadStatus newStatus;
        if (launchpad.raised >= launchpad.goal) {
            newStatus = LaunchpadStatus.VOTING;
        } else if (launchpad.raised > 0) {
            uint256 requiredVotingAmount = (launchpad.raised * s_requiredVotingBps) / 10000;
            if (launchpad.raised >= requiredVotingAmount) {
                newStatus = LaunchpadStatus.WAITING;
            } else {
                newStatus = LaunchpadStatus.REFUNDING;
                s_refundingLaunchpads.push(launchpadId);
            }
        } else {
            newStatus = LaunchpadStatus.FAILED;
        }

        launchpad.status = newStatus;
        emit LaunchpadStatusUpdated(launchpadId, currentStatus, newStatus);
    }

    function refundLaunchpad(string memory launchpadId, address refundContract, bytes32 receiversRoot)
        external
        onlyOwner
    {
        Launchpad storage launchpad = s_launchpads[launchpadId];
        if (launchpad.status != LaunchpadStatus.REFUNDING) {
            revert InvalidStatus(launchpad.status, LaunchpadStatus.REFUNDING);
        }
        launchpad.status = LaunchpadStatus.REFUNDED;
        IERC20(launchpad.token).safeIncreaseAllowance(refundContract, launchpad.raised);
        ICourseLaunchpadRefund(refundContract).createRefund(
            launchpadId, launchpad.token, launchpad.raised, receiversRoot
        );
        _removeRefundingLaunchpad(launchpadId);

        emit LaunchpadStatusUpdated(launchpadId, LaunchpadStatus.REFUNDING, LaunchpadStatus.REFUNDED);
    }

    function endLaunchpad(string memory launchpadId, bool isSuccessful) external onlyOwner {
        Launchpad storage launchpad = s_launchpads[launchpadId];
        LaunchpadStatus currentStatus = launchpad.status;

        if (currentStatus != LaunchpadStatus.VOTING) {
            revert InvalidStatus(currentStatus, LaunchpadStatus.VOTING);
        }

        LaunchpadStatus newStatus = isSuccessful ? LaunchpadStatus.SUCCESSFUL : LaunchpadStatus.REFUNDING;
        launchpad.status = newStatus;

        if (!isSuccessful) {
            s_refundingLaunchpads.push(launchpadId);
        }

        emit LaunchpadStatusUpdated(launchpadId, currentStatus, newStatus);
    }

    function acceptFunding(string memory launchpadId) external onlyLaunchpadOwner(launchpadId) {
        Launchpad storage launchpad = s_launchpads[launchpadId];
        if (launchpad.status != LaunchpadStatus.WAITING) {
            revert InvalidStatus(launchpad.status, LaunchpadStatus.WAITING);
        }
        launchpad.status = LaunchpadStatus.VOTING;
        emit LaunchpadStatusUpdated(launchpadId, LaunchpadStatus.WAITING, LaunchpadStatus.VOTING);
    }

    /*//////////////////////////////////////////////////////////////
                      LAUNCHPAD SETTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function emergencyChangeStatus(string memory launchpadId, LaunchpadStatus status) external onlyOwner {
        if (s_launchpads[launchpadId].status != LaunchpadStatus.INIT) {
            revert InvalidStatus(s_launchpads[launchpadId].status, LaunchpadStatus.INIT);
        }
        s_launchpads[launchpadId].status = status;

        emit LaunchpadStatusUpdated(launchpadId, LaunchpadStatus.INIT, status);
    }

    function completeVotingPhase(string memory launchpadId, uint256 availableClaim) external onlyOwner {
        Launchpad storage launchpad = s_launchpads[launchpadId];
        if (launchpad.status != LaunchpadStatus.VOTING) revert InvalidStatus(launchpad.status, LaunchpadStatus.VOTING);
        launchpad.availableClaim = availableClaim;
        launchpad.raised -= availableClaim;

        emit LaunchpadStatusUpdated(launchpadId, LaunchpadStatus.VOTING, LaunchpadStatus.WAITING);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function initLaunchpad(
        string memory launchpadId,
        address launchpadOwner,
        address token,
        uint256 goal,
        uint256 startFundingTime,
        uint256 endFundingTime,
        uint256 minPledgeAmount
    ) public payable {
        if (s_launchpads[launchpadId].owner != address(0)) {
            revert LaunchpadAlreadyExists(launchpadId);
        }

        if (msg.value != s_requiredStakeAmount) {
            revert InvalidAmount(msg.value, s_requiredStakeAmount);
        }

        s_launchpads[launchpadId] = Launchpad({
            owner: launchpadOwner,
            token: token,
            goal: goal,
            availableClaim: 0,
            totalPledged: 0,
            raised: 0,
            startFundingTime: startFundingTime,
            endFundingTime: endFundingTime,
            stakeAmount: msg.value,
            minPledgeAmount: minPledgeAmount,
            status: LaunchpadStatus.INIT
        });

        emit LaunchpadCreated(launchpadId, launchpadOwner, token, goal, startFundingTime, endFundingTime);
    }

    function pledgeNative(string memory launchpadId) public payable onlyFundingLaunchpad(launchpadId) {
        Launchpad storage launchpad = s_launchpads[launchpadId];

        if (launchpad.token != address(0)) revert InvalidToken(launchpad.token);
        if (msg.value < launchpad.minPledgeAmount) {
            revert InvalidAmount(msg.value, launchpad.minPledgeAmount);
        }

        uint256 maxPledgeAmount = (launchpad.goal * s_maxPledgeBps) / 10000;
        if (s_backerBalances[launchpadId][msg.sender] + msg.value > maxPledgeAmount) {
            revert InvalidAmount(msg.value, maxPledgeAmount);
        }

        launchpad.raised += msg.value;
        launchpad.totalPledged += msg.value;
        s_backerBalances[launchpadId][msg.sender] += msg.value;

        emit FundingAction(launchpadId, msg.sender, msg.value, "pledge");
    }

    function pledgeERC20(string memory launchpadId, uint256 amount) public onlyFundingLaunchpad(launchpadId) {
        Launchpad storage launchpad = s_launchpads[launchpadId];
        if (launchpad.token == address(0)) revert InvalidToken(address(0));
        if (amount < launchpad.minPledgeAmount) {
            revert InvalidAmount(amount, launchpad.minPledgeAmount);
        }

        uint256 maxPledgeAmount = (launchpad.goal * s_maxPledgeBps) / 10000;
        if (s_backerBalances[launchpadId][msg.sender] + amount > maxPledgeAmount) {
            revert InvalidAmount(amount, maxPledgeAmount);
        }

        IERC20(launchpad.token).safeTransferFrom(msg.sender, address(this), amount);
        launchpad.raised += amount;
        launchpad.totalPledged += amount;
        s_backerBalances[launchpadId][msg.sender] += amount;

        emit FundingAction(launchpadId, msg.sender, amount, "pledge");
    }

    function claimFunding(string memory launchpadId) public onlyLaunchpadOwner(launchpadId) {
        Launchpad storage launchpad = s_launchpads[launchpadId];
        if (launchpad.availableClaim == 0) {
            revert InvalidAmount(launchpad.availableClaim, 0);
        }

        uint256 claimAmount = launchpad.availableClaim;
        launchpad.availableClaim = 0;
        IERC20(launchpad.token).safeTransfer(launchpad.owner, claimAmount);

        emit FundingAction(launchpadId, launchpad.owner, claimAmount, "claim");
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _removeRefundingLaunchpad(string memory _value) public returns (bool) {
        uint256 length = s_refundingLaunchpads.length;
        for (uint256 i = 0; i < length; i++) {
            if (keccak256(bytes(s_refundingLaunchpads[i])) == keccak256(bytes(_value))) {
                for (uint256 j = i; j < length - 1; j++) {
                    s_refundingLaunchpads[j] = s_refundingLaunchpads[j + 1];
                }
                s_refundingLaunchpads.pop();
                return true;
            }
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getAllRefundingLaunchpads() external view returns (string[] memory) {
        return s_refundingLaunchpads;
    }

    function getLaunchpad(string memory launchpadId) external view returns (Launchpad memory) {
        return s_launchpads[launchpadId];
    }

    function getBackerBalance(string memory launchpadId, address backer) external view returns (uint256) {
        return s_backerBalances[launchpadId][backer];
    }
}
