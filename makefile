-include .env

.PHONY: deploy-and-verify clean

# Network selection (default to sepolia if not specified)
NETWORK ?= base-sepolia

# Deploy fee receiver contract
deploy-fee-receiver:
	@echo "🚀 Deploying FeeReceiver contract to ${NETWORK}..."
	@forge script script/deploy/DeployFeeReceiver.s.sol:DeployFeeReceiver --account ${ACCOUNT_CAST_WALLET} --rpc-url ${NETWORK} --etherscan-api-key ${BASESCAN_API_KEY} --broadcast --verify -vvvv

# Deploy mock USDC contract
deploy-mock-usdc:
	@echo "🚀 Deploying MockUSDC contract to ${NETWORK}..."
	@forge script script/deploy/DeployMockUSDC.s.sol:DeployMockUSDC --account ${ACCOUNT_CAST_WALLET} --rpc-url ${NETWORK} --etherscan-api-key ${BASESCAN_API_KEY} --broadcast --verify -vvvv

# Deploy course payment contract
deploy-course-payment:
	@echo "🚀 Deploying CoursePayment contract to ${NETWORK}..."
	@forge script script/deploy/DeployCoursePayment.s.sol:DeployCoursePayment --account ${ACCOUNT_CAST_WALLET} --rpc-url ${NETWORK} --etherscan-api-key ${BASESCAN_API_KEY} --broadcast --verify -vvvv

# Clean artifacts and cache
clean:
	@echo "🧹 Cleaning..."
	@forge clean