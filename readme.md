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
  - Certificate: [0x420adAd0e1DB47D4e3fffD834c7c003AB14934ba](https://basescan.org/address/0x420adAd0e1DB47D4e3fffD834c7c003AB14934ba)
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
