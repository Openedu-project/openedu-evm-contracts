// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Launchpad {
    // Constants
    uint128 public constant DEFAULT_MIN_STAKING = 0.00001 ether; // 0.00001 ETH equivalent to 1 NEAR

    // Enums
    enum Status {
        INIT,
        APPROVED,
        FUNDING,
        REJECTED,
        CANCELED,
        FAILED,
        WAITING,
        REFUNDED,
        VOTING,
        CLOSED,
        SUCCESSFUL
    }

    // Structs
    struct PoolMetadata {
        uint256 poolId;
        string campaignId;
        address creatorId;
        uint256 stakingAmount;
        Status status;
        address tokenId;
        uint256 totalBalance;
        uint256 targetFunding;
        uint256 timeInit;
        uint256 timeStartPledge;
        uint256 timeEndPledge;
        uint256 fundingDurationDays;
        uint256 minMultiplePledge;
        address[] backers;
    }

    struct Assets {
        address tokenId;
        uint256 balances;
    }

    struct UserTokenDepositRecord {
        uint256 amount;
        uint256 votingPower; // Changed from float to uint256 for voting power
    }

    struct UserRecordDetail {
        address userId;
        UserTokenDepositRecord record;
    }

    // State Variables
    address public ownerId;
    uint256[] public allPoolIds;
    Assets[] public listAssets;
    mapping(uint256 => PoolMetadata) public poolMetadataById;
    uint256 public minStakingAmount;
    uint8 public refundPercent;
    mapping(uint256 => mapping(address => UserTokenDepositRecord))
        public userRecords;

    // Events
    event PoolCreated(uint256 poolId, address creator);
    event UserDeposited(uint256 poolId, address user, uint256 amount);
    event StatusChanged(uint256 poolId, Status newStatus);

    // Constructor
    constructor(
        address _ownerId,
        uint256 _minStakingAmount,
        uint8 _refundPercent
    ) {
        ownerId = _ownerId;
        minStakingAmount = _minStakingAmount;
        refundPercent = _refundPercent;
    }

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == ownerId, "Only owner can call this function");
        _;
    }

    modifier validPoolId(uint256 poolId) {
        require(poolId > 0, "Invalid pool ID");
        _;
    }

    /* Admin Features  */

    // Add token
    function addAsset(address tokenId) external onlyOwner {
        require(tokenId != address(0), "Invalid token address");

        // Check if asset already exists
        for (uint i = 0; i < listAssets.length; i++) {
            require(listAssets[i].tokenId != tokenId, "Asset already exists");
        }

        // Create and add new asset with default balance of 0
        Assets memory newAsset = Assets({tokenId: tokenId, balances: 0});

        listAssets.push(newAsset);
    }
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != ownerId, "New owner cannot be current owner");

        address oldOwner = ownerId;
        ownerId = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // Admin check pool status after initialization of 15 days
    function adminCheckPoolStatusAfterInit15Days(
        uint256 poolId
    ) external onlyOwner validPoolId(poolId) {
        PoolMetadata storage pool = poolMetadataById[poolId];
        require(pool.status == Status.INIT, "Pool must be in INIT status");

        uint256 fifteenDays = 15 days;
        require(
            block.timestamp > pool.timeInit + fifteenDays,
            "Not yet 15 days"
        );

        uint256 refundAmount;
        if (refundPercent == 0) {
            refundAmount = minStakingAmount; // Changed from 1 ETH to 0.00001 ETH
        } else {
            require(refundPercent <= 100, "Invalid refund percent");
            refundAmount = (pool.stakingAmount * refundPercent) / 100;
        }

        // Send funds using call to avoid gas limit issues with transfer
        (bool success, ) = payable(pool.creatorId).call{value: refundAmount}(
            ""
        );
        require(success, "Refund failed");

        // Update pool status
        pool.status = Status.REJECTED;
        pool.stakingAmount = 0;

        emit PoolRejected(poolId, refundPercent, refundAmount, pool.creatorId);
    }

    function adminSetStatusPoolPreFunding(
        uint256 poolId,
        bool approve
    ) external onlyOwner validPoolId(poolId) {
        PoolMetadata storage pool = poolMetadataById[poolId];
        require(pool.status == Status.INIT, "Pool must be in INIT status");

        if (approve) {
            pool.status = Status.APPROVED;
            emit PoolApproved(poolId, pool.creatorId);
        } else {
            uint256 refundAmount;
            if (refundPercent == 0) {
                refundAmount = minStakingAmount; // Changed from 1 ETH to 0.00001 ETH
            } else {
                require(refundPercent <= 100, "Invalid refund percent");
                refundAmount = (pool.stakingAmount * refundPercent) / 100;
            }

            require(
                refundAmount <= pool.stakingAmount,
                "Refund exceeds staking amount"
            );

            // Use call to send funds safely, avoiding issues if creatorId is a smart contract
            (bool success, ) = payable(pool.creatorId).call{
                value: refundAmount
            }("");
            require(success, "Refund failed");

            pool.status = Status.REJECTED;
            pool.stakingAmount = 0;

            emit PoolRejected(
                poolId,
                refundPercent,
                refundAmount,
                pool.creatorId
            );
        }
    }

    function adminCheckFundingResult(
        uint256 poolId,
        bool isWaitingFunding
    ) external onlyOwner validPoolId(poolId) {
        PoolMetadata storage pool = poolMetadataById[poolId];
        require(
            pool.status == Status.FUNDING,
            "Pool must be in FUNDING status"
        );
        require(
            block.timestamp > pool.timeEndPledge,
            "Funding period has not ended yet"
        );

        // Calculate voting power for backers
        if (pool.totalBalance > 0) {
            for (uint i = 0; i < pool.backers.length; i++) {
                address backer = pool.backers[i];
                UserTokenDepositRecord storage record = userRecords[poolId][
                    backer
                ];
                record.votingPower = (record.amount * 100) / pool.totalBalance; // Updated to use uint256
            }
        }

        if (pool.totalBalance == 0) {
            pool.status = Status.FAILED;
            emit PoolStatusChanged(poolId, Status.FAILED, "Zero total balance");
        } else if (pool.totalBalance >= pool.targetFunding) {
            pool.status = Status.VOTING;
            emit PoolStatusChanged(
                poolId,
                Status.VOTING,
                "Reached target funding"
            );
        } else if (
            pool.totalBalance >= (pool.targetFunding * 80) / 100 &&
            isWaitingFunding
        ) {
            pool.status = Status.WAITING;
            pool.timeEndPledge += 3 days;
            emit PoolStatusChanged(
                poolId,
                Status.WAITING,
                "Extended funding period"
            );
        } else {
            pool.status = Status.REFUNDED;
            emit PoolStatusChanged(
                poolId,
                Status.REFUNDED,
                "Did not reach minimum funding"
            );
        }
    }

    /* User Features  */

    // Main functions would go here
    function createPool(
        string memory campaignId,
        address tokenId,
        uint256 targetFunding,
        uint256 minMultiplePledge
    ) external payable {
        // Require sending at least 0.0001 ETH
        require(msg.value >= 0.0001 ether, "Insufficient ETH sent");

        // Generate new pool ID
        uint256 poolId = allPoolIds.length + 1;

        require(
            bytes(poolMetadataById[poolId].campaignId).length == 0,
            "Pool already exists"
        );

        // Validate inputs
        require(targetFunding > 0, "Target funding must be greater than 0");
        require(minMultiplePledge > 0, "Minimum pledge must be greater than 0");
        require(tokenId != address(0), "Token address cannot be zero");

        // Check if token is supported
        bool isTokenSupported = false;
        for (uint i = 0; i < listAssets.length; i++) {
            if (listAssets[i].tokenId == tokenId) {
                isTokenSupported = true;
                break;
            }
        }
        require(isTokenSupported, "Token not supported");

        address[] memory backers = new address[](0);

        PoolMetadata memory newPool = PoolMetadata({
            poolId: poolId,
            campaignId: campaignId,
            creatorId: msg.sender,
            stakingAmount: minStakingAmount,
            status: Status.INIT,
            tokenId: tokenId,
            totalBalance: 0,
            targetFunding: targetFunding,
            timeInit: block.timestamp,
            timeStartPledge: 0,
            timeEndPledge: 0,
            fundingDurationDays: 0,
            minMultiplePledge: minMultiplePledge,
            backers: backers
        });

        poolMetadataById[poolId] = newPool;
        allPoolIds.push(poolId);

        emit PoolCreated(poolId, msg.sender);
    }

    function setFundingPoolByCreator(
        uint256 poolId,
        uint256 timeStartPledge,
        uint256 fundingDurationDays
    ) external validPoolId(poolId) {
        PoolMetadata storage pool = poolMetadataById[poolId];

        require(
            msg.sender == pool.creatorId,
            "Only the creator of the pool can set funding parameters"
        );
        require(
            pool.status == Status.APPROVED,
            "Pool must be in APPROVED status"
        );
        require(
            fundingDurationDays > 0,
            "Funding duration must be greater than 0 days"
        );
        require(
            timeStartPledge > block.timestamp,
            "Start time must be in the future"
        );

        pool.timeStartPledge = timeStartPledge;
        pool.timeEndPledge = timeStartPledge + (fundingDurationDays * 1 days);
        pool.fundingDurationDays = fundingDurationDays;
        pool.status = Status.FUNDING;

        emit PoolFundingSet(poolId, timeStartPledge, fundingDurationDays);
    }

    function cancelPool(uint256 poolId) external validPoolId(poolId) {
        PoolMetadata storage pool = poolMetadataById[poolId];

        require(
            msg.sender == pool.creatorId,
            "Only the creator of the pool can cancel it"
        );
        require(
            pool.status == Status.INIT,
            "Pool must be in INIT status to be canceled"
        );

        uint256 refundAmount = pool.stakingAmount;
        payable(pool.creatorId).transfer(refundAmount);

        pool.status = Status.CANCELED;
        pool.stakingAmount = 0;

        emit PoolCanceled(poolId, refundAmount, pool.creatorId);
    }

    function creatorAcceptVoting(
        uint256 poolId,
        bool approve
    ) external validPoolId(poolId) {
        PoolMetadata storage pool = poolMetadataById[poolId];

        require(
            msg.sender == pool.creatorId,
            "Only the creator can set the pool status after waiting"
        );
        require(
            pool.status == Status.WAITING,
            "Pool status must be WAITING to change it after waiting period"
        );

        if (approve) {
            pool.status = Status.VOTING;
            emit CreatorAcceptedVoting(poolId, pool.creatorId);
        } else {
            pool.status = Status.REFUNDED;
            emit CreatorRejectedVoting(poolId, pool.creatorId);
        }
    }

    function depositToken(
        uint256 poolId,
        uint256 amount
    ) external validPoolId(poolId) {
        PoolMetadata storage pool = poolMetadataById[poolId];

        require(
            pool.status == Status.FUNDING,
            "Pool must be in FUNDING status"
        );

        require(
            block.timestamp >= pool.timeStartPledge &&
                block.timestamp <= pool.timeEndPledge,
            "Not within pledge period"
        );
        
        // Check user approval for token on contract
        require(
            IERC20(pool.tokenId).allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance, please approve more tokens"
        );

        // Transfer tokens from user to contract
        require(
            IERC20(pool.tokenId).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            "Token transfer failed"
        );

        // Update user records
        UserTokenDepositRecord storage userRecord = userRecords[poolId][
            msg.sender
        ];
        userRecord.amount += amount;
        userRecord.votingPower = 0; // Will be calculated later

        // Add backer to pool if not already added
        bool isNewBacker = true;
        for (uint i = 0; i < pool.backers.length; i++) {
            if (pool.backers[i] == msg.sender) {
                isNewBacker = false;
                break;
            }
        }
        if (isNewBacker) {
            pool.backers.push(msg.sender);
        }

        // Update pool total balance
        pool.totalBalance += amount;

        emit TokenDeposited(poolId, msg.sender, amount);
    }

    function claimRefund(uint256 poolId) external validPoolId(poolId) {
        address callerId = msg.sender;

        PoolMetadata storage pool = poolMetadataById[poolId];
        require(
            pool.status == Status.REFUNDED,
            "Pool is not in REFUNDED status"
        );

        UserTokenDepositRecord storage userRecord = userRecords[poolId][
            callerId
        ];
        require(userRecord.amount > 0, "User has no record in this pool");

        uint256 refundAmount = uint256(
            (pool.totalBalance * userRecord.votingPower) / 100
        );

        require(refundAmount > 0, "No funds available for withdrawal");

        // Transfer the refund amount back to the user
        require(
            IERC20(pool.tokenId).transfer(callerId, refundAmount),
            "Token transfer failed"
        );

        // Update the user's record amount to 0
        userRecord.amount = 0;

        emit TokenDeposited(poolId, callerId, refundAmount); // Log the refund event
    }

    /* Get Method */

    function getPoolMetadata(
        uint256 poolId
    ) external view validPoolId(poolId) returns (PoolMetadata memory) {
        return poolMetadataById[poolId];
    }

    function isTokenSupported(address tokenId) external view returns (bool) {
        for (uint i = 0; i < listAssets.length; i++) {
            if (listAssets[i].tokenId == tokenId) {
                return true;
            }
        }
        return false;
    }

    function getAllPool() external view returns (PoolMetadata[] memory) {
        PoolMetadata[] memory pools = new PoolMetadata[](allPoolIds.length);
        for (uint i = 0; i < allPoolIds.length; i++) {
            pools[i] = poolMetadataById[allPoolIds[i]];
        }
        return pools;
    }

    function getPoolsByStatus(
        Status status
    ) external view returns (PoolMetadata[] memory) {
        uint256 count = 0;
        for (uint i = 0; i < allPoolIds.length; i++) {
            if (poolMetadataById[allPoolIds[i]].status == status) {
                count++;
            }
        }

        PoolMetadata[] memory pools = new PoolMetadata[](count);
        uint256 index = 0;
        for (uint i = 0; i < allPoolIds.length; i++) {
            if (poolMetadataById[allPoolIds[i]].status == status) {
                pools[index] = poolMetadataById[allPoolIds[i]];
                index++;
            }
        }
        return pools;
    }

    function getDetailPool(
        uint256 poolId
    ) external view validPoolId(poolId) returns (PoolMetadata memory) {
        return poolMetadataById[poolId];
    }

    function getBalanceCreator(
        uint256 poolId
    ) external view validPoolId(poolId) returns (uint256) {
        return poolMetadataById[poolId].stakingAmount;
    }

    function getMinStakingAmount() external view returns (uint128) {
        return DEFAULT_MIN_STAKING;
    }

    function getUserRecordsByPoolId(
        uint256 poolId
    )
        external
        view
        validPoolId(poolId)
        returns (UserTokenDepositRecord[] memory)
    {
        // Implement logic to return user records for the specified pool
        return new UserTokenDepositRecord[](0); // Placeholder
    }

    function getCurrentTimestamp() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    /* Event */
    event TokenDeposited(uint256 poolId, address user, uint256 amount);

    event PoolApproved(uint256 poolId, address creator);

    event PoolRejected(
        uint256 poolId,
        uint256 refundPercent,
        uint256 refundAmount,
        address creator
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event PoolFundingSet(
        uint256 poolId,
        uint256 timeStartPledge,
        uint256 fundingDurationDays
    );

    event PoolCanceled(uint256 poolId, uint256 refundAmount, address creator);

    event CreatorAcceptedVoting(uint256 poolId, address creator);
    event CreatorRejectedVoting(uint256 poolId, address creator);
    event PoolStatusChanged(uint256 poolId, Status status, string reason);

}