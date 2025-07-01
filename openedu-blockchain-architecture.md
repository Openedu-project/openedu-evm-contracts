# OpenEdu Blockchain Architecture Documentation

## 🎯 Overview

OpenEdu blockchain system consists of two main services:
- **openedu-core**: Main business logic, user management
- **openedu-blockchain**: Blockchain operations, wallet management, transaction processing

### Key Design Principles
- **Microservice Architecture**: Separated concerns between business logic and blockchain
- **Async Communication**: RabbitMQ message queues for service-to-service communication
- **Multi-Network Support**: NEAR, BASE (Ethereum L2), AVAIL
- **Strategy Pattern**: Easy to add new blockchain networks
- **Security First**: Private key encryption, secure transaction handling

## 🏗️ Service Architecture

```
┌─────────────────┐                 ┌──────────────────────┐
│   openedu-core  │                 │ openedu-blockchain   │
│                 │                 │                      │
│                 │                 │ • Wallet Management  │
│ • Business Logic│                 │ • Transaction Proc.  │
│ • User Mgmt     │                 │ • NFT Minting        │
│ • Course Mgmt   │                 │ • Launchpad          │
└─────────────────┘                 └──────────────────────┘
         │                                       │
         │              RabbitMQ                 │
         └──────────── Queues Only ──────────────┘
         │                                       │
         ▼                                       ▼
┌─────────────────┐                 ┌──────────────────────┐
│   PostgreSQL    │                 │   PostgreSQL         │
│   (Core DB)     │                 │   (Blockchain DB)    │
└─────────────────┘                 └──────────────────────┘
```

### 🔒 **Security-First Communication**
- **NO REST APIs** between services
- **RabbitMQ message queues ONLY** for service-to-service communication
- **Async processing** for all blockchain operations
- **Complete isolation** between business logic and blockchain logic

### Database Separation
- **Core DB**: Users, courses, organizations, business data
- **Blockchain DB**: Wallets, transactions, sponsor wallets, blockchain-specific data


## 🔄 Communication Flow

### 1. Message Queue Pattern

**Core → Blockchain:**
```go
// openedu-core/pkg/openedu_chain/
producer.Publish(queueName, message)
```

**Blockchain → Core:**
```go
// openedu-blockchain/pkg/openedu_core/
producer.Publish(queueName, syncMessage)
```

### 2. Queue Types

#### 📤 **Core → Blockchain Queues**
| Queue Name                    | Purpose                | Handler                   |
| ----------------------------- | ---------------------- | ------------------------- |
| `wallet_create_queue`         | Create new wallets     | `CreateWallet`            |
| `sponsor_wallet_create_queue` | Create sponsor wallets | `CreateSponsorWallet`     |
| `transaction_create_queue`    | Process transactions   | `CreateTransaction`       |
| `launchpad_rpc_query`         | Launchpad operations   | `HandleLaunchpadRPCQuery` |
| `wallet_rpc_query`            | Wallet queries         | `HandleWalletRPCQuery`    |

#### 📥 **Blockchain → Core Queues**
| Queue Name                          | Purpose                 | Handler                       |
| ----------------------------------- | ----------------------- | ----------------------------- |
| `wallet_sync_queue`                 | Sync wallet data        | `SyncWallet`                  |
| `transaction_sync_queue`            | Sync transaction status | `SyncTransaction`             |
| `wallet_retrieve_get_details_queue` | Wallet details          | `HandleRetrieveWalletDetails` |

### 3. RPC vs Fire-and-Forget

**RPC Pattern** (Request-Response):
```go
// For queries that need immediate response
repliedMsg, err := producer.PublishRPC(queueName, message)
```

**Fire-and-Forget Pattern**:
```go
// For async operations
err := producer.Publish(queueName, message)
```

## 🚀 Blockchain Features

### 1. 🎯 NFT Minting System

**Supported Networks:**
- **NEAR**: Native NEAR NFT contracts
- **BASE**: Ethereum L2 with EIP-712 permits

**Gas Fee Payers:**
- `Platform`: OpenEdu pays gas fees
- `Learner`: Student pays gas fees
- `Creator`: Course creator pays via sponsor wallet
- `Paymaster`: Coinbase Paymaster (BASE only)

**Transaction Types:**
- `mint_nft`: Standard NFT minting
- `mint_nft_with_permit`: EIP-712 permit-based minting (BASE)

**Flow:**
```
1. User completes course
2. Core validates completion
3. Core → Queue: MintNFT request
4. Blockchain processes minting
5. Blockchain → Queue: Transaction sync
6. Core updates certificate status
```

Flow Diagram: https://www.canva.com/design/DAGlcCklLrY/6WJDomdRtdigTHaef62e6A/view?utm_content=DAGlcCklLrY&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=h5954fa7160

### 2. 💰 Wallet Management

**Wallet Types:**
- **Crypto Wallets**: ETH, NEAR, USDT, USDC, OpenEdu token
- **Multi-Network**: NEAR, BASE, AVAIL support
- **Sponsor Wallets**: Gas fee sponsoring (BASE only)

**Supported Operations:**
- Wallet creation and sync
- Balance tracking across networks
- Private key encryption with KMS
- Account info retrieval

**Multi-Network Support:**
```go
// Strategy pattern for different networks
type WalletStrategy interface {
    CreateWallet(req *CreateWalletRequest) (*CreateWalletResponse, error)
    GetBalance(address string) (decimal.Decimal, error)
}
```

### 3. 💸 Transfer System

**Transfer Types:**
- **Single Transfer**: One-to-one transfers
- **Batch Transfer**: One-to-many transfers
- **Cross-Network**: Transfer between different blockchains

**Supported Tokens:**
- **Native Tokens**: ETH (BASE), NEAR (NEAR), AVAIL (AVAIL)
- **Fungible Tokens**: USDT, USDC, custom tokens
- **Multi-Network**: Each network supports its native and fungible tokens

**Transfer Strategies:**
- `eth_2_eth`: Ethereum-based transfers (BASE network)
- `near_2_near`: NEAR protocol transfers
- `avail_2_avail`: AVAIL blockchain transfers

**Flow:**
```
1. Core validates transfer request
2. Core → Queue: Transfer request
3. Blockchain selects appropriate strategy
4. Strategy executes transfer on blockchain
5. Blockchain → Queue: Transaction sync
6. Core updates balances
```

### 4. 🏦 Sponsor Wallet System

**Purpose**: Allow course creators to sponsor gas fees for their students

**Features:**
- **BASE network only**
- **ETH deposits** for gas fee sponsoring
- **Balance tracking** and management
- **Automatic fallback** to paymaster if insufficient balance

**Operations:**
- `deposit_sponsor_gas`: Add funds to sponsor wallet
- `withdraw_sponsor_gas`: Remove funds from sponsor wallet
- `init_sponsor_wallet`: Initialize new sponsor wallet

**Flow:**
```
1. Creator creates sponsor wallet
2. Creator deposits ETH
3. Student mints NFT
4. Gas fee deducted from sponsor wallet
```

### 5. 💳 Payment System

**Purpose**: Handle crypto payments for courses and services

**Features:**
- **Multi-token support**: ETH, USDT, USDC, custom tokens
- **Multi-network**: NEAR, BASE, AVAIL
- **Automatic conversion**: Token to fiat equivalent
- **Payment validation**: Balance and network checks

**Transaction Type:**
- `payment`: Process payment transactions

### 6. 🎁 Earning Claims System

**Purpose**: Allow users to claim earned rewards and tokens

**Features:**
- **Reward distribution**: Automatic token distribution
- **Claim validation**: Verify eligibility before claiming
- **Multi-token support**: Various reward tokens
- **Batch claims**: Multiple rewards in single transaction

**Transaction Type:**
- `claim_earning`: Process earning claims

### 7. 🚀 Launchpad System

**Purpose**: Crowdfunding platform for educational projects

**Features:**
- **Pool creation** with funding goals
- **Milestone-based** fund release
- **Voting mechanisms** for milestone approval
- **Refund system** if goals not met
- **Multi-network support**

**Transaction Types:**
- `init_launchpad_pool`: Create new funding pool
- `approve_launchpad_pool`: Approve pool for funding
- `pledge_launchpad`: Pledge funds to pool
- `withdraw_launchpad_fund_to_creator`: Release funds to creator
- `claim_launchpad_refund`: Claim refund if pool fails

Flow Diagram: https://www.canva.com/design/DAGYH252Uqg/oNyh-VFamfIUs9vwaxL3sw/view?utm_content=DAGYH252Uqg&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=h94d9465a34

## 🗄️ Database Schema

### Blockchain Service Database Tables

#### 1. **openedu_transactions**
```sql
-- Main transaction table storing all blockchain operations
CREATE TABLE openedu_transactions (
    id VARCHAR(20) PRIMARY KEY,
    create_at BIGINT NOT NULL DEFAULT 0,
    update_at BIGINT NOT NULL DEFAULT 0,
    delete_at BIGINT NOT NULL DEFAULT 0,
    wallet_id TEXT,
    core_tx_id TEXT, -- Reference to core service transaction
    from_address TEXT,
    to_address TEXT,
    status TEXT, -- pending, success, failed
    error_code BIGINT,
    type TEXT, -- transaction type (see below)
    tx_hash TEXT, -- blockchain transaction hash
    deposit TEXT, -- amount as string for precision
    gas_price BIGINT,
    gas_limit BIGINT,
    gas_burnt BIGINT,
    nonce BIGINT,
    block_hash TEXT,
    response JSONB, -- blockchain response data
    method_name TEXT, -- smart contract method called
    input_data JSONB, -- method parameters
    token TEXT, -- token type (ETH, NEAR, USDT, etc.)
    contract_id TEXT, -- smart contract address
    is_mainnet BOOLEAN, -- mainnet vs testnet
    props JSONB, -- additional properties
    from_network TEXT, -- source network
    to_network TEXT -- destination network
);
```

**Key Features:**
- **Unified transaction storage** for all blockchain operations
- **Cross-network support** with from_network/to_network fields
- **Flexible JSONB fields** for network-specific data
- **Gas tracking** for cost analysis
- **Core service integration** via core_tx_id

#### 2. **openedu_wallets**
```sql
-- Multi-network wallet storage
CREATE TABLE openedu_wallets (
    id VARCHAR(20) PRIMARY KEY,
    create_at BIGINT NOT NULL DEFAULT 0,
    update_at BIGINT NOT NULL DEFAULT 0,
    delete_at BIGINT NOT NULL DEFAULT 0,
    user_id TEXT, -- reference to core service user
    address TEXT, -- blockchain address
    public_key TEXT,
    encrypted_private_key TEXT, -- KMS encrypted private key
    network TEXT, -- base, near, avail
    status TEXT, -- active, inactive, pending
    balance TEXT, -- balance as string for precision
    core_wallet_id TEXT UNIQUE -- reference to core service wallet
);
```

**Key Features:**
- **Multi-network support** with network field
- **Secure key storage** with encryption
- **Core service integration** via core_wallet_id
- **Balance tracking** as string for decimal precision

#### 3. **openedu_sponsor_wallets**
```sql
-- Sponsor wallets for gas fee sponsoring
CREATE TABLE openedu_sponsor_wallets (
    id VARCHAR(20) PRIMARY KEY,
    create_at BIGINT NOT NULL DEFAULT 0,
    update_at BIGINT NOT NULL DEFAULT 0,
    delete_at BIGINT NOT NULL DEFAULT 0,
    wallet_id TEXT, -- reference to openedu_wallets
    sponsor_id TEXT, -- user ID of sponsor (creator)
    sponsor_name TEXT,
    description TEXT,
    balance TEXT, -- sponsor balance as string
    network TEXT, -- currently only 'base'
    status TEXT, -- active, inactive
    address TEXT DEFAULT '', -- sponsor wallet address
    encrypted_private_key TEXT DEFAULT '', -- encrypted private key
    user_id TEXT, -- duplicate of sponsor_id for indexing
    public_key TEXT,
    core_wallet_id TEXT -- reference to core service
);
```

**Key Features:**
- **Gas fee sponsoring** for course creators
- **BASE network only** currently supported
- **Multiple indexes** for efficient queries
- **Integrated with regular wallets** via wallet_id

#### 4. **openedu_user_settings**
```sql
-- User blockchain settings and seed phrases
CREATE TABLE openedu_user_settings (
    user_id TEXT, -- reference to core service user
    encrypted_seed_phrase TEXT, -- encrypted mnemonic phrase
    encrypted_secret TEXT -- additional encrypted secrets
);
```

**Key Features:**
- **Seed phrase storage** for wallet recovery
- **Encrypted secrets** for additional security
- **User-specific settings** for blockchain preferences

### Core Service Database Integration

The core service maintains its own database with references to blockchain wallets:

```sql
-- In openedu-core database
CREATE TABLE wallets (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR NOT NULL,
    currency VARCHAR NOT NULL, -- ETH, NEAR, USDT, etc.
    network VARCHAR NOT NULL, -- base, near, avail
    address VARCHAR,
    blockchain_wallet_id VARCHAR, -- References openedu_wallets.id
    balance DECIMAL DEFAULT 0,
    status VARCHAR DEFAULT 'pending',
    created_at BIGINT,
    updated_at BIGINT
);
```

### Data Flow Between Services

```
1. Core creates wallet record (blockchain_wallet_id = null)
2. Core → Queue: Create wallet request
3. Blockchain creates wallet with private key
4. Blockchain → Queue: Wallet sync with blockchain_wallet_id
5. Core updates wallet record with blockchain_wallet_id
```

## 🛠️ Development Guide

### Adding New Blockchain Network

1. **Create Strategy Implementation:**
```go
// openedu-blockchain/services/nft/strategies/new_network.go
type NewNetworkMintNftService struct{}

func (s *NewNetworkMintNftService) MintNFT(account Account, req *MintNftRequest) (*MintNftResponse, error) {
    // Implementation
}
```

2. **Register Strategy:**
```go
// openedu-blockchain/services/services.go
nftSvc.RegisterStrategy(models.NetworkNEW, &strategies.NewNetworkMintNftService{})
```

3. **Add Network Constants:**
```go
// models/constant.go
NetworkNEW BlockchainNetwork = "new_network"
```

### Adding New Transaction Type

1. **Define DTO:**
```go
// dto/transaction.go
type NewTransactionRequest struct {
    // Fields
}
```

2. **Implement Service Method:**
```go
// services/transaction.go
func (s *TransactionService) NewTransaction(req *dto.NewTransactionRequest) (*models.Transaction, *e.AppError) {
    // Implementation
}
```

3. **Add Queue Handler:**
```go
// queues/handlers/transaction.go
// Handle new transaction type
```

### Environment Configuration

**Core Service (.env):**
```bash
# RabbitMQ
RABBITMQ_URL=amqp://localhost:5672
RABBITMQ_PREFIX=openedu_

# Blockchain Service
OPENEDU_CHAIN_MAINNET=false
```

**Blockchain Service (.env):**
```bash
# Private Keys
PLATFORM_PRIVATE_KEY_TESTNET=
PLATFORM_PRIVATE_KEY_MAINNET=
```

## 🔧 Troubleshooting

### Common Issues

#### 1. **Queue Connection Failed**
```bash
# Check RabbitMQ status
sudo systemctl status rabbitmq-server

# Check queue consumers
rabbitmqctl list_consumers

# List all queues with message counts
rabbitmqctl list_queues name messages consumers
```

#### 2. **Transaction Stuck in Pending**
```sql
-- Check pending transactions in blockchain service
SELECT id, type, status, wallet_id, created_at
FROM openedu_transactions
WHERE status = 'pending'
ORDER BY created_at DESC;

-- Check failed transactions
SELECT id, type, error_code, response
FROM openedu_transactions
WHERE status = 'failed'
ORDER BY created_at DESC;
```

#### 3. **Sponsor Wallet Issues**
```sql
-- Check sponsor wallet balance
SELECT sponsor_id, network, balance, status
FROM openedu_sponsor_wallets
WHERE sponsor_id = 'user_id';

-- Check sponsor wallet transactions
SELECT * FROM openedu_transactions
WHERE type IN ('deposit_sponsor_gas', 'withdraw_sponsor_gas', 'init_sponsor_wallet')
ORDER BY created_at DESC;
```

#### 4. **Transfer Failures**
```sql
-- Check transfer transactions
SELECT id, from_address, to_address, value, token, status, response
FROM openedu_transactions
WHERE type IN ('transfer', 'batch_transfer')
AND status = 'failed'
ORDER BY created_at DESC;
```

#### 5. **NFT Minting Issues**
```sql
-- Check NFT minting transactions
SELECT id, wallet_id, status, props, response
FROM openedu_transactions
WHERE type = 'mint_nft'
ORDER BY created_at DESC;
```

### Debugging Commands

#### Database Queries
```sql
-- Check wallet sync status
SELECT id, user_id, network, address, status
FROM openedu_wallets
WHERE status != 'active';

-- Check transaction distribution by type
SELECT type, status, COUNT(*) as count
FROM openedu_transactions
GROUP BY type, status
ORDER BY type, status;

-- Check recent activity
SELECT type, status, COUNT(*) as count
FROM openedu_transactions
WHERE created_at > EXTRACT(EPOCH FROM NOW() - INTERVAL '1 hour') * 1000
GROUP BY type, status;
```

#### Queue Monitoring
```bash
# Check specific queue status
rabbitmqctl list_queue_bindings

# Monitor queue activity in real-time
watch -n 2 'rabbitmqctl list_queues name messages consumers'

# Check queue message rates
rabbitmqctl list_queues name message_stats.publish_details.rate
```

### Monitoring

**Key Metrics to Monitor:**
- Queue message count and processing rate
- Transaction success/failure rates by type
- Wallet creation and sync rates
- Gas fee consumption and sponsor wallet balances
- Network RPC response times
- Database connection pool usage

**Critical Alerts:**
- Queue messages > 1000 (potential bottleneck)
- Failed transaction rate > 5%
- Wallet sync failures
- RPC endpoint downtime
- Database connection failures

### Performance Optimization

1. **Queue Workers**: Adjust worker pool sizes based on load
   - Transaction processing: 20-50 workers
   - Wallet operations: 10-30 workers
   - NFT minting: 10-20 workers

2. **Database Indexing**: Ensure proper indexes
   ```sql
   CREATE INDEX idx_transactions_status ON openedu_transactions(status);
   CREATE INDEX idx_transactions_type ON openedu_transactions(type);
   CREATE INDEX idx_transactions_wallet_id ON openedu_transactions(wallet_id);
   CREATE INDEX idx_wallets_user_network ON openedu_wallets(user_id, network);
   ```

3. **RPC Optimization**:
   - Use connection pooling for RPC clients
   - Implement retry logic with exponential backoff
   - Cache static data (contract addresses, network configs)

4. **Batch Processing**:
   - Use batch transfers for multiple recipients
   - Batch database operations where possible
   - Implement transaction batching for high-volume operations

---

## 📝 Summary

This OpenEdu blockchain architecture provides:

### ✅ **Comprehensive Features**
- **7 Major Blockchain Features**: NFT minting, transfers, payments, sponsor wallets, earning claims, launchpad, wallet management
- **Multi-Network Support**: NEAR, BASE (Ethereum L2), AVAIL
- **Multiple Transaction Types**: 12+ different transaction types supported
- **Flexible Gas Fee Management**: Platform, learner, creator, and paymaster options


### 🔒 **Security & Reliability**
- **Private Key Encryption**: KMS-based key management
- **Transaction Validation**: Multi-layer validation before execution
- **Error Handling**: Comprehensive error codes and retry mechanisms
- **Monitoring**: Built-in logging and performance tracking
