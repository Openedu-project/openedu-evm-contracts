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
  - Certificate: [0x0f61205637d02a0799d981a4d9547751a74fb9fc](https://sepolia.basescan.org/address/0x0f61205637d02a0799d981a4d9547751a74fb9fc)
  
### Mainnet

- Base:
  - Certificate: [0x1cc085A6b7c12167359D026fa044a18364380C89](https://basescan.org/address/0x1cc085A6b7c12167359D026fa044a18364380C89)
    - Owner: 0x19b970Aa6038Cb582EE191A49B3978ceEd255815 [Terran Hold Key]
  - Badge: [0xA278DF5A2E5B136916C2c62851A717C64d9E6cE3](https://basescan.org/address/0xA278DF5A2E5B136916C2c62851A717C64d9E6cE3)
    - Owner: 0x19b970Aa6038Cb582EE191A49B3978ceEd255815 [Terran Hold Key]
    

## Verify Contract

```bash
forge verify-contract \
    0xA278DF5A2E5B136916C2c62851A717C64d9E6cE3 \
    src/SponsorNFT.sol:SponsorNFT \
    --etherscan-api-key ${ETHERSCAN_API_KEY} \
    --chain 8453 \
    --rpc-url ${BASE_MAINNET_RPC_URL} \
    --constructor-args $(cast abi-encode "constructor(address,string,string)" 0x19b970Aa6038Cb582EE191A49B3978ceEd255815 "OpenEdu Badge" "OEB") \
    --watch
```

## Contracts Overview

### SponsorNFT (`src/SponsorNFT.sol`)
SponsorNFT is an ERC-721 compliant NFT used to represent supporters / badge holders.

Key points:
- Inherits `ERC721`, `ERC721URIStorage`, `AccessControl`, `Ownable2Step`, and `EIP712`.
- Role-based access (`DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`).
- `mint` allows authorised minters to issue NFTs.
- `mintWithPermit` lets anyone mint using an off-chain signature from the contract owner (gasless UX) with replay-protection via nonce + signatureId mapping.
- Admin can update metadata through `updateTokenUri`.

### CourseLaunchpad (`src/CourseLaunchpad.sol`)
On-chain launchpad that enables educators to crowdfund the creation of new courses.

Highlights:
- Maintains per-course *Launchpad* objects with funding goal, raised amount, status enum (`INIT → APPROVED → FUNDING → ...`).
- Backers pledge ERC-20 tokens (optionally via `permit`) and are subject to configurable limits (`s_maxPledgeBps`, `s_maxFundingBps`, etc.).
- Owner actions for approving/rejecting/cancelling a launchpad and tuning global parameters.
- Emits rich events for off-chain indexers.
- When funding fails or only partially succeeds the contract cooperates with `CourseLaunchpadRefund` to reimburse backers.

### CourseLaunchpadRefund (`src/CourseLaunchpadRefund.sol`)
Handles the refund workflow after a launchpad ends in a *REFUNDING* state.
- Stores RefundInfo (token, amount, receiversRoot) per launchpad.
- Assets are transferred in from `CourseLaunchpad` during `createRefund`.
- Eligible users prove inclusion in the Merkle tree and present an EIP-712 signature to `claimRefund`.
- Prevents double claims via `s_isClaimed` mapping.

### CoursePayment (`src/CoursePayment.sol`)
Simple one-off payment contract for purchasing course access.
- Supports payment with allowed ERC-20 tokens.
- `payWithPermit` enables gasless payments.
- Funds are split between `Vault` (course proceeds) and `FeeReceiver` (protocol fee).

### Vault (`src/Vault.sol`)
Custody contract that holds course proceeds in ERC-20s.
- Only owner (governance) can withdraw specific amounts.
- Withdrawals can direct a fee portion to `FeeReceiver`.

### FeeReceiver (`src/FeeReceiver.sol`)
Accumulates protocol fees and allows owner to sweep all tokens.

### Interfaces
`ICourseLaunchpad.sol` & `ICourseLaunchpadRefund.sol` define the minimal APIs that external contracts/tools can rely on.

---

> ℹ️  All contracts are written for Solidity `0.8.26` and rely on OpenZeppelin Contracts `v5.2.0`. They are developed & tested with Foundry `v1.0.0-nightly`.
