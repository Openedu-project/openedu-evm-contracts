# OpenEdu EVM Contracts

## Libraries
- foundry@v1.0.0-nightly
- openzeppelin-contracts@v5.2.0
- foundry-devops@0.3.2

## Deployed Contracts
### Testnet
- Base Sepolia
  - MockUSDC: [0x7c20e41909c1cbfc82df5ee8b7cb7760d36be0a2](https://sepolia.basescan.org/address/0x7c20e41909c1cbfc82df5ee8b7cb7760d36be0a2)
  - CoursePayment: [0x71c7b75e656370319031b2058c4c2d477049fcb0](https://sepolia.basescan.org/address/0x71c7b75e656370319031b2058c4c2d477049fcb0)
  - Vault: [0x598a623e890b5a4811e35d12c7824c9ca676064c](https://sepolia.basescan.org/address/0x598a623e890b5a4811e35d12c7824c9ca676064c)
  - FeeReceiver: [0xf42a42e4810ca8b7a80fb613c88a8756ad49f2b5](https://sepolia.basescan.org/address/0xf42a42e4810ca8b7a80fb613c88a8756ad49f2b5)
  - CourseLaunchpad: [0x00d2Af3Fb85cEA186006cf379E119219E2102e5e](https://sepolia.basescan.org/address/0x00d2af3fb85cea186006cf379e119219e2102e5e)
  - CourseLaunchpadRefund: [0xdb75C2c839fbcF7D77b6e148431Afb06d0d2ed70](https://sepolia.basescan.org/address/0xdb75c2c839fbcf7d77b6e148431afb06d0d2ed70)
### Mainnet
... 

## Course Launchpad

1. Launchpad Campaign có 2 loại: 
- Native token (pledge bằng ETH)
- Token ERC20 (bất kỳ loại nào)

2. Tạo một campagin thì dùng:

```solidity
initLaunchpad(
        string memory launchpadId,
        address launchpadOwner,
        address token,
        uint256 goal,
        uint256 minPledgeAmount
)
```

- `launchpadId` là do backend quy định, nên có một hàm (hoặc một endpoint) để lấy được launchpadId cho phía client nếu dùng web3 wallet.
- `launchpadOwner` là người tạo ra launchpad (creator).
- `token` nếu muốn pledge bằng native token thì để là `address(0)` 0x0000000000000000000000000000000000000000, còn nếu là token thì nhập token address.
- `goal` là số tiền mục tiêu
- `minPledgeAmount` là số tiền tối thiểu để pledge cho một campagin

3. Admin function:

- Sau khi launchpad được tạo thì admin có thể dùng function `approveLaunchpad()` để chấp nhận launchpad. Nhưng chưa pledge được tiền, campaign owner phải set ngày gọi vốn nữa thì mới được, tức là họ muốn gọi vốn trong vòng bao lâu?
- Hiện tại có thể gọi vốn trong 30 ngày (được setting sẵn), để bắt đầu gọi vốn campaign owner gọi function `startFunding()`

4. Pledge: 
Sau khi đã chạy 3 function trên:
- `initLaunchpad()`,`approveLaunchpad()`,`startFunding()`, lúc này campaign sẽ nằm ở status FUNDING trên contract nên user có thể pledge tiền được rồi.
- Đối với launchpad native, user sử dụng function `pledgeNative()` để pledge tiền.
- Đối với launchpad token, user sử dụng function `pledgeERC20()`, có thể tuỳ chọn `pledgeERC20withPermit()` để owner sponsor gas với fee được tự động tính toán và truyền vào trên backend.

5. Kết quả của campaign (được gọi là hành động kết thúc một cuộc funding, end funding):
- Admin sử dụng hàm `endFundingResult()` để contract tự động tính toán kết quả của launchpad đó.

```solidity
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
```

- Nếu launchpad raised (số tiền thu được) lớn hơn goal sẽ được chuyển sang trạng thái VOTING.
- Nếu launchpad raised được hơn 80% trên goal, thì sẽ chuyển sang trạng thái WAITING, ở đây campaign owner phải có hành động chuyển từ WAITING -> VOTING thì mới tiếp tục campaign (bằng hàm `acceptFunding()`). Nếu không đồng ý sẽ chuyển status của campaign thành REFUNDING.
- Nếu launchpad raised dưới 80% thì trên goal thì sẽ được chuyển sang trạng thái REFUNDING. 
- Nếu không raised được đồng nào thì sẽ chuyển thành FAILED.

5. Refund:
- Để refund cho một campaign thì admin cần có danh sách refunding campaign thông qua hàm `getAllRefundingLaunchpads()`.
- Backend handle danh sách backers + số dư refund của họ chuyển thành dạng merkleTree, tham khảo function backend service tại: https://github.com/vbi-blockchain/evm-test-service.
- Gọi hàm `refundLaunchpad(string memory launchpadId, address refundContract, bytes32 receiversRoot)` để refund cho user, khi chạy xong hàm này campaign của user sẽ chuyển status thành REFUNDED. 
- Backend cần lưu một danh sách user, đối với một launchpadId cần có:
  - merkleRoot
  - user vào với số dư nào
  - đã được claim hay chưa

User claim refund:

- Để claim refund user gọi:

``` solidity
claimRefund(
    string memory launchpadId,
    address account, 
    uint256 amount,
    bytes32[] calldata merkleProof,
    uint8 v,
    bytes32 r,
    bytes32 s
)
```

Ví dụ sử dụng hàm này cũng có tại [backend service](https://github.com/vbi-blockchain/evm-test-service) tại launchpad service.

6. Voting

7. End launchpad