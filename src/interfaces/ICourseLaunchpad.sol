// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICourseLaunchpad {
    /*//////////////////////////////////////////////////////////////
                                  TYPE
    //////////////////////////////////////////////////////////////*/
    enum LaunchpadStatus {
        INIT,
        REJECTED,
        CANCELLED,
        APPROVED,
        FUNDING,
        FAILED,
        WAITING,
        REFUNDING,
        REFUNDED,
        VOTING,
        SUCCESSFUL
    }

    struct Launchpad {
        address owner;
        address token;
        uint256 goal;
        uint256 totalPledged; // cumulative balance, not for calculation
        uint256 raised;
        uint256 availableClaim;
        uint256 startFundingTime;
        uint256 endFundingTime;
        uint256 stakeAmount;
        uint256 minPledgeAmount;
        LaunchpadStatus status;
    }

    /*//////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvalidAmount(uint256 provided, uint256 required);
    error InvalidToken(address token);
    error InvalidStatus(LaunchpadStatus current, LaunchpadStatus required);
    error InvalidFundingDuration(uint256 provided, uint256 required);
    error Unauthorized(address caller, string reason);
    error TransactionFailed(string reason);
    error LaunchpadAlreadyExists(string launchpadId);

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/
    event LaunchpadCreated(string indexed launchpadId, address indexed owner, address indexed token, uint256 goal);
    event LaunchpadStatusUpdated(string indexed launchpadId, LaunchpadStatus oldStatus, LaunchpadStatus newStatus);
    event FundingAction(string indexed launchpadId, address indexed actor, uint256 amount, string actionType); // actionType: "pledge", "claim", "refund"
    event VotingResult(string indexed launchpadId, uint256 availableClaim, bool successful);
}
