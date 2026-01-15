# RWA-EVM-Smart-Contract

A professional, enterprise-grade Real World Assets (RWA) tokenization smart contract suite built for EVM-compatible blockchains. This comprehensive solution enables the tokenization of real-world assets (real estate, commodities, art, securities, etc.) as ERC20 tokens with advanced compliance, governance, and operational features.

## 🚀 Key Features

### Core Tokenization
- **Asset Tokenization**: Tokenize real-world assets as ERC20 tokens with fractional ownership
- **Multi-Asset Support**: Factory pattern for deploying multiple RWA tokens
- **Custody Management**: Built-in custodian role and management
- **Document Management**: On-chain document hash storage (IPFS integration ready)

### Compliance & Security
- **Role-Based Access Control**: Comprehensive role system (Admin, Minter, Compliance, Pauser, Custodian, Oracle, Redemption)
- **KYC/AML Integration**: Interface for external KYC/AML provider integration
- **Whitelist/Blacklist**: Advanced compliance controls
- **Transfer Restrictions**: Configurable transfer limits and restrictions
- **Pausable Functionality**: Emergency pause mechanism for security incidents

### Financial Features
- **Dividend Distribution**: Automated dividend distribution to token holders
- **Redemption Mechanism**: Token redemption with configurable fees
- **Fee Management**: Flexible fee system for transfers, minting, and redemptions
- **Oracle Integration**: Real-time valuation updates via price oracles
- **Valuation Management**: On-chain and oracle-based valuation tracking

### Governance & Operations
- **Governance System**: Token-based voting for asset management decisions
- **Time Locks**: Critical operation delays for security
- **Vesting Schedules**: Token vesting with cliff and duration support
- **Proposal System**: Structured proposal and voting mechanism

### Professional Architecture
- **Modular Design**: Separate contracts for different concerns
- **Interface-Based**: Clean interfaces for extensibility
- **Library Support**: Reusable calculation libraries
- **Event Logging**: Comprehensive event system for off-chain tracking

## 📁 Project Structure

```
RWA-EVM-Smart-Contract/
├── contracts/
│   ├── interfaces/
│   │   ├── IRWAToken.sol          # RWA Token interface
│   │   ├── IOracle.sol            # Oracle interface for price feeds
│   │   └── IKYCProvider.sol       # KYC/AML provider interface
│   ├── libraries/
│   │   └── RWALibrary.sol         # Utility functions and calculations
│   ├── RWAToken.sol               # Main RWA tokenization contract
│   ├── RWAFactory.sol             # Factory for deploying RWA tokens
│   ├── RWADividend.sol            # Dividend distribution contract
│   ├── RWAVesting.sol             # Token vesting schedule contract
│   ├── RWATimelock.sol            # Time lock for critical operations
│   ├── RWAFeeManager.sol          # Fee management system
│   └── RWAGoverning.sol           # Governance and voting contract
├── scripts/
│   └── deploy.js                  # Deployment script
├── test/
│   └── RWAToken.test.js           # Comprehensive test suite
├── hardhat.config.js              # Hardhat configuration
├── package.json                   # Dependencies and scripts
└── README.md                      # This file
```

## 🛠️ Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd RWA-EVM-Smart-Contract
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   Create a `.env` file in the root directory:
   ```env
   # Network RPC URLs
   SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID
   MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID
   
   # Private Key (without 0x prefix)
   PRIVATE_KEY=your_private_key_here
   
   # Etherscan API Key for contract verification
   ETHERSCAN_API_KEY=your_etherscan_api_key
   
   # Optional deployment configuration
   TOKEN_NAME=Real Estate Token
   TOKEN_SYMBOL=RET
   ASSET_TYPE=Real Estate
   ASSET_ID=RE-001
   DESCRIPTION=Commercial property in downtown
   VALUATION=1000000
   ```

## 📖 Usage

### Compile Contracts

```bash
npm run compile
```

### Run Tests

```bash
npm run test
```

### Deploy Contracts

**Local Network:**
```bash
npm run node  # In one terminal
npm run deploy:local  # In another terminal
```

**Sepolia Testnet:**
```bash
npm run deploy:sepolia
```

**Mainnet:**
```bash
npm run deploy:mainnet
```

## 📚 Contract Architecture

### RWAToken (Main Contract)

The core tokenization contract with comprehensive features:

#### Roles
- **DEFAULT_ADMIN_ROLE**: Full administrative control
- **MINTER_ROLE**: Can mint new tokens
- **COMPLIANCE_ROLE**: Manages whitelist, blacklist, and compliance settings
- **PAUSER_ROLE**: Can pause/unpause token transfers
- **REDEMPTION_ROLE**: Can execute token redemptions
- **CUSTODIAN_ROLE**: Asset custodian with special permissions
- **ORACLE_ROLE**: Can update valuations from oracle

#### Key Functions

**Token Management:**
- `mint(address to, uint256 amount)`: Mint tokens (with KYC checks if enabled)
- `burn(uint256 amount)`: Burn tokens
- `burnFrom(address from, uint256 amount)`: Burn tokens from address

**Compliance:**
- `addToWhitelist(address account)`: Add to whitelist
- `addToBlacklist(address account)`: Add to blacklist
- `setTransferLimit(address account, uint256 limit)`: Set per-address transfer limits
- `toggleKYCRequired()`: Enable/disable KYC requirements

**Asset Management:**
- `updateValuation(uint256 newValuation)`: Update asset valuation
- `updateValuationFromOracle()`: Update from oracle (ORACLE_ROLE)
- `updateCustodian(address newCustodian)`: Change asset custodian
- `addDocument(string documentType, string documentHash)`: Add document hash

**Redemption:**
- `requestRedemption(uint256 amount)`: Request token redemption
- `executeRedemption(address requester, uint256 amount)`: Execute redemption (REDEMPTION_ROLE)
- `getRedemptionValue(uint256 tokenAmount)`: Calculate redemption value

**Integration:**
- `setOracle(address oracleAddress)`: Set price oracle
- `setKYCProvider(address providerAddress)`: Set KYC/AML provider
- `setFeeManager(address feeManagerAddress)`: Set fee manager contract
- `setVestingContract(address vestingAddress)`: Set vesting contract
- `setDividendContract(address dividendAddress)`: Set dividend contract

**View Functions:**
- `getAssetInfo()`: Get complete asset information
- `getTokenPrice()`: Get current token price (uses oracle if available)
- `getOwnershipPercentage(address account)`: Get ownership percentage
- `getAssetValue(address account)`: Get asset value owned by account
- `canTransfer(address from, address to)`: Check if transfer is allowed

### RWAFactory

Factory contract for deploying multiple RWA tokens:

```solidity
function deployRWAToken(
    string memory name,
    string memory symbol,
    address initialOwner,
    string memory assetType,
    string memory assetId,
    string memory description,
    uint256 valuation,
    address custodian,
    string memory documentHash
) external returns (address)
```

### RWADividend

Dividend distribution to token holders:

- `createDividendPeriod(uint256 totalAmount)`: Create new dividend period
- `claimDividend(uint256 periodId)`: Claim dividends for a period
- `getClaimableDividend(address account, uint256 periodId)`: Check claimable amount

### RWAVesting

Token vesting with schedules:

- `createVestingSchedule(...)`: Create vesting schedule with cliff and duration
- `release(address beneficiary, uint256 scheduleId)`: Release vested tokens
- `revoke(address beneficiary, uint256 scheduleId)`: Revoke vesting (if revocable)

### RWATimelock

Time lock for critical operations:

- `queue(...)`: Queue a transaction with delay
- `execute(...)`: Execute queued transaction after delay
- `cancel(...)`: Cancel queued transaction

### RWAFeeManager

Flexible fee management:

- `calculateFee(uint256 amount, string feeType)`: Calculate fee
- `collectFee(...)`: Collect fee (integrated with transfers)
- `updateFeeConfig(...)`: Update fee configuration
- `setFeeExempt(address account, bool exempt)`: Set fee exemption

### RWAGoverning

Token-based governance:

- `createProposal(...)`: Create governance proposal
- `castVote(uint256 proposalId, Vote vote)`: Vote on proposal
- `executeProposal(uint256 proposalId)`: Execute successful proposal

## 🔐 Security Features

- **Access Control**: Role-based permissions for all operations
- **Input Validation**: Comprehensive validation of all inputs
- **Pausable**: Emergency stop mechanism
- **Time Locks**: Delays for critical operations
- **Compliance**: KYC/AML, whitelist, blacklist support
- **OpenZeppelin**: Uses battle-tested OpenZeppelin contracts

## 📊 Example Usage

### 1. Deploy RWA Token

```javascript
const RWAToken = await ethers.getContractFactory("RWAToken");
const rwaToken = await RWAToken.deploy(
  "Real Estate Token",
  "RET",
  ownerAddress,
  "Real Estate",
  "RE-001",
  "Commercial property in downtown",
  ethers.parseEther("1000000"), // $1M valuation
  custodianAddress,
  "QmHash..." // IPFS hash
);
```

### 2. Set Up Integrations

```javascript
// Set oracle
await rwaToken.setOracle(oracleAddress);

// Set KYC provider
await rwaToken.setKYCProvider(kycProviderAddress);

// Set fee manager
await rwaToken.setFeeManager(feeManagerAddress);
```

### 3. Configure Compliance

```javascript
// Enable KYC
await rwaToken.toggleKYCRequired();

// Add to whitelist
await rwaToken.addToWhitelist(investorAddress);

// Enable transfer restrictions
await rwaToken.toggleTransferRestrictions();
```

### 4. Mint Tokens

```javascript
await rwaToken.connect(minter).mint(investorAddress, ethers.parseEther("1000"));
```

### 5. Set Up Dividend Distribution

```javascript
const RWADividend = await ethers.getContractFactory("RWADividend");
const dividend = await RWADividend.deploy(
  rwaTokenAddress,
  usdcAddress // Payment token
);

await rwaToken.setDividendContract(dividendAddress);
await dividend.createDividendPeriod(ethers.parseUnits("10000", 6)); // $10k USDC
```

### 6. Request Redemption

```javascript
await rwaToken.requestRedemption(ethers.parseEther("100"));
await rwaToken.connect(redemptionRole).executeRedemption(investorAddress, ethers.parseEther("100"));
```

## 🌐 Network Support

This contract suite is compatible with all EVM-compatible blockchains:

- **Ethereum** (Mainnet, Sepolia, Goerli)
- **Polygon**
- **Arbitrum**
- **Optimism**
- **BSC** (Binance Smart Chain)
- **Avalanche**
- **Base**
- And other EVM-compatible networks

## 🧪 Testing

The test suite includes comprehensive coverage for:
- Contract deployment
- Token minting and burning
- Transfer functionality with all restrictions
- Compliance features (KYC, whitelist, blacklist)
- Redemption mechanism
- Dividend distribution
- Vesting schedules
- Governance voting
- Fee management
- Time locks
- Role-based access control

Run tests with:
```bash
npm run test
```

## 📝 License

MIT

## ⚠️ Disclaimer

This smart contract suite is provided as-is for educational and development purposes. Always conduct thorough security audits before deploying to mainnet. The authors are not responsible for any losses or damages resulting from the use of these contracts.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

For issues, questions, or contributions, please open an issue on the repository.

## 🔄 Version History

- **v1.0.0**: Initial release with core tokenization features
- **v2.0.0**: Professional release with modular architecture, governance, dividends, vesting, and comprehensive compliance features
