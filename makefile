-include .env

.PHONY: deploy-and-verify clean

# Network selection (default to sepolia if not specified)
NETWORK ?= base-sepolia

# Deploy fee receiver contract
deploy-fee-receiver:
	@echo "🚀 Deploying FeeReceiver contract to ${NETWORK}..."
	@forge script script/deploy/DeployFeeReceiver.s.sol:DeployFeeReceiver --account ${ACCOUNT_CAST_WALLET} --rpc-url ${NETWORK} --etherscan-api-key ${BASESCAN_API_KEY} --broadcast --verify -vvvv

# Deploy vault contract
deploy-vault:
	@echo "🚀 Deploying Vault contract to ${NETWORK}..."
	@forge script script/deploy/DeployVault.s.sol:DeployVault --account ${ACCOUNT_CAST_WALLET} --rpc-url ${NETWORK} --etherscan-api-key ${BASESCAN_API_KEY} --broadcast --verify -vvvv

# Deploy mock USDC contract
deploy-mock-usdc:
	@echo "🚀 Deploying MockUSDC contract to ${NETWORK}..."
	@forge script script/deploy/DeployMockUSDC.s.sol:DeployMockUSDC --account ${ACCOUNT_CAST_WALLET} --rpc-url ${NETWORK} --etherscan-api-key ${BASESCAN_API_KEY} --broadcast --verify -vvvv

# Deploy course payment contract
deploy-course-payment:
	@echo "🚀 Deploying CoursePayment contract to ${NETWORK}..."
	@forge script script/deploy/DeployCoursePayment.s.sol:DeployCoursePayment --account ${ACCOUNT_CAST_WALLET} --rpc-url ${NETWORK} --etherscan-api-key ${BASESCAN_API_KEY} --broadcast --verify -vvvv

# Deploy course launchpad contract
deploy-course-launchpad:
	@echo "🚀 Deploying CourseLaunchpad contract to ${NETWORK}..."
	@forge script script/deploy/DeployCourseLaunchpad.s.sol:DeployCourseLaunchpad --account ${ACCOUNT_CAST_WALLET} --rpc-url ${NETWORK} --etherscan-api-key ${BASESCAN_API_KEY} --broadcast --verify -vvvv

# Deploy course launchpad refund contract
deploy-course-launchpad-refund:
	@echo "🚀 Deploying CourseLaunchpadRefund contract to ${NETWORK}..."
	@forge script script/deploy/DeployCourseLaunchpadRefund.s.sol:DeployCourseLaunchpadRefund --account ${ACCOUNT_CAST_WALLET} --rpc-url ${NETWORK} --etherscan-api-key ${BASESCAN_API_KEY} --broadcast --verify -vvvv

# Deploy certificate contract
deploy-certificate:
	@echo "🚀 Deploying Certificate contract to ${NETWORK}..."
	@forge script script/deploy/DeployCertificate.s.sol:DeployCertificate --account ${ACCOUNT_CAST_WALLET} --rpc-url ${NETWORK} --etherscan-api-key ${BASESCAN_API_KEY} --broadcast --verify -vvvv

# Clean artifacts and cache
clean:
	@echo "🧹 Cleaning..."
	@forge clean