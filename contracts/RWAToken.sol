// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IRWAToken.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IKYCProvider.sol";
import "./libraries/RWALibrary.sol";

/**
 * @title RWAToken
 * @dev Professional Real World Assets (RWA) Tokenization Smart Contract
 * 
 * This contract provides enterprise-grade tokenization of real-world assets with:
 * - Advanced compliance and regulatory features
 * - Oracle integration for real-time valuation
 * - KYC/AML provider integration
 * - Redemption mechanisms
 * - Document and custody management
 * - Fee management integration
 * - Governance hooks
 */
contract RWAToken is ERC20, ERC20Pausable, AccessControl, Ownable, IRWAToken {
    using SafeERC20 for IERC20;

    // Role definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant REDEMPTION_ROLE = keccak256("REDEMPTION_ROLE");
    bytes32 public constant CUSTODIAN_ROLE = keccak256("CUSTODIAN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // Enhanced Asset metadata
    AssetInfo public override assetInfo;

    // Transfer restrictions
    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;
    bool public whitelistEnabled;
    bool public transferRestrictionsEnabled;
    bool public kycRequired;

    // External integrations
    IOracle public oracle;
    IKYCProvider public kycProvider;
    address public feeManager;
    address public vestingContract;
    address public dividendContract;

    // Redemption mechanism
    bool public redemptionEnabled;
    uint256 public redemptionFee; // Basis points
    IERC20 public redemptionToken; // Token used for redemption (e.g., USDC)
    mapping(address => uint256) public redemptionRequests;
    uint256 public totalRedemptionRequests;

    // Transfer limits
    mapping(address => uint256) public transferLimits; // Per-address transfer limits
    bool public transferLimitsEnabled;

    // Document management
    mapping(string => string) public documents; // documentType => documentHash/IPFS hash
    string[] public documentTypes;

    // Events
    event AssetTokenized(
        string indexed assetType,
        string indexed assetId,
        uint256 valuation,
        address indexed custodian,
        uint256 tokenizationDate
    );
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event TransferRestrictionsToggled(bool enabled);
    event WhitelistToggled(bool enabled);
    event AssetValuationUpdated(uint256 oldValuation, uint256 newValuation, uint256 timestamp);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event KYCProviderUpdated(address indexed oldProvider, address indexed newProvider);
    event KYCRequiredToggled(bool required);
    event RedemptionRequested(address indexed requester, uint256 tokenAmount, uint256 expectedValue);
    event RedemptionExecuted(address indexed requester, uint256 tokenAmount, uint256 redemptionValue);
    event RedemptionToggled(bool enabled);
    event DocumentAdded(string indexed documentType, string documentHash);
    event DocumentUpdated(string indexed documentType, string oldHash, string newHash);
    event CustodianUpdated(address indexed oldCustodian, address indexed newCustodian);
    event TransferLimitSet(address indexed account, uint256 limit);
    event TransferLimitsToggled(bool enabled);
    event FeeManagerUpdated(address indexed oldFeeManager, address indexed newFeeManager);
    event VestingContractUpdated(address indexed oldContract, address indexed newContract);
    event DividendContractUpdated(address indexed oldContract, address indexed newContract);

    /**
     * @dev Constructor
     * @param name Token name
     * @param symbol Token symbol
     * @param initialOwner Initial owner of the contract
     * @param assetType Type of real-world asset
     * @param assetId Unique identifier for the asset
     * @param description Asset description
     * @param valuation Initial asset valuation in USD (scaled by 1e18)
     * @param custodian Address of the asset custodian
     * @param documentHash IPFS hash or hash of legal documents
     */
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner,
        string memory assetType,
        string memory assetId,
        string memory description,
        uint256 valuation,
        address custodian,
        string memory documentHash
    ) ERC20(name, symbol) Ownable(initialOwner) {
        require(initialOwner != address(0), "RWAToken: owner cannot be zero address");
        require(custodian != address(0), "RWAToken: custodian cannot be zero address");
        require(RWALibrary.isValidValuation(valuation), "RWAToken: invalid valuation");

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, initialOwner);
        _grantRole(COMPLIANCE_ROLE, initialOwner);
        _grantRole(PAUSER_ROLE, initialOwner);
        _grantRole(REDEMPTION_ROLE, initialOwner);
        _grantRole(CUSTODIAN_ROLE, custodian);

        // Initialize asset info
        assetInfo = AssetInfo({
            assetType: assetType,
            assetId: assetId,
            description: description,
            valuation: valuation,
            tokenizationDate: block.timestamp,
            isActive: true,
            custodian: custodian,
            documentHash: documentHash
        });

        whitelistEnabled = false;
        transferRestrictionsEnabled = false;
        kycRequired = false;
        redemptionEnabled = false;
        transferLimitsEnabled = false;

        if (bytes(documentHash).length > 0) {
            documents["legal"] = documentHash;
            documentTypes.push("legal");
        }

        emit AssetTokenized(assetType, assetId, valuation, custodian, block.timestamp);
    }

    /**
     * @dev Mint tokens (only for MINTER_ROLE)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(assetInfo.isActive, "RWAToken: asset is not active");
        require(to != address(0), "RWAToken: cannot mint to zero address");
        require(amount > 0, "RWAToken: amount must be greater than zero");
        
        if (kycRequired && address(kycProvider) != address(0)) {
            require(kycProvider.isKYCVerified(to), "RWAToken: recipient not KYC verified");
        }

        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from caller
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Burn tokens from specified address (only for MINTER_ROLE)
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burnFrom(address from, uint256 amount) public onlyRole(MINTER_ROLE) {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }

    /**
     * @dev Override transfer with enhanced compliance checks
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        require(assetInfo.isActive, "RWAToken: asset is not active");
        
        // KYC checks
        if (kycRequired && address(kycProvider) != address(0)) {
            if (from != address(0)) {
                require(kycProvider.isKYCVerified(from), "RWAToken: sender not KYC verified");
            }
            if (to != address(0)) {
                require(kycProvider.isKYCVerified(to), "RWAToken: recipient not KYC verified");
            }
        }

        // Transfer limits
        if (transferLimitsEnabled && from != address(0)) {
            uint256 limit = transferLimits[from];
            if (limit > 0) {
                require(value <= limit, "RWAToken: transfer exceeds limit");
            }
        }
        
        // Compliance checks
        if (transferRestrictionsEnabled) {
            require(!blacklist[from], "RWAToken: sender is blacklisted");
            require(!blacklist[to], "RWAToken: recipient is blacklisted");
            
            if (whitelistEnabled) {
                require(whitelist[from] || from == address(0), "RWAToken: sender not whitelisted");
                require(whitelist[to] || to == address(0), "RWAToken: recipient not whitelisted");
            }
        }

        super._update(from, to, value);
    }

    /**
     * @dev Request redemption of tokens
     * @param amount Amount of tokens to redeem
     */
    function requestRedemption(uint256 amount) external {
        require(redemptionEnabled, "RWAToken: redemption not enabled");
        require(amount > 0, "RWAToken: amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "RWAToken: insufficient balance");

        redemptionRequests[msg.sender] += amount;
        totalRedemptionRequests += amount;

        uint256 expectedValue = _calculateRedemptionValue(amount);
        emit RedemptionRequested(msg.sender, amount, expectedValue);
    }

    /**
     * @dev Execute redemption (only for REDEMPTION_ROLE)
     * @param requester Address requesting redemption
     * @param amount Amount of tokens to redeem
     */
    function executeRedemption(address requester, uint256 amount) external onlyRole(REDEMPTION_ROLE) {
        require(redemptionRequests[requester] >= amount, "RWAToken: insufficient redemption request");
        require(address(redemptionToken) != address(0), "RWAToken: redemption token not set");

        uint256 redemptionValue = _calculateRedemptionValue(amount);
        uint256 fee = (redemptionValue * redemptionFee) / 10000;
        uint256 netValue = redemptionValue - fee;

        redemptionRequests[requester] -= amount;
        totalRedemptionRequests -= amount;

        _burn(requester, amount);
        redemptionToken.safeTransfer(requester, netValue);

        emit RedemptionExecuted(requester, amount, netValue);
    }

    /**
     * @dev Calculate redemption value for tokens
     */
    function _calculateRedemptionValue(uint256 tokenAmount) internal view returns (uint256) {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) return 0;
        
        uint256 currentValuation = assetInfo.valuation;
        if (address(oracle) != address(0)) {
            try oracle.getLatestPrice() returns (uint256 oraclePrice) {
                if (oraclePrice > 0) {
                    currentValuation = oraclePrice;
                }
            } catch {}
        }

        return (tokenAmount * currentValuation) / totalSupply;
    }

    /**
     * @dev Pause token transfers (only for PAUSER_ROLE)
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause token transfers (only for PAUSER_ROLE)
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Compliance functions
    function addToWhitelist(address account) public onlyRole(COMPLIANCE_ROLE) {
        require(account != address(0), "RWAToken: cannot whitelist zero address");
        whitelist[account] = true;
        emit WhitelistUpdated(account, true);
    }

    function removeFromWhitelist(address account) public onlyRole(COMPLIANCE_ROLE) {
        whitelist[account] = false;
        emit WhitelistUpdated(account, false);
    }

    function addToBlacklist(address account) public onlyRole(COMPLIANCE_ROLE) {
        require(account != address(0), "RWAToken: cannot blacklist zero address");
        blacklist[account] = true;
        emit BlacklistUpdated(account, true);
    }

    function removeFromBlacklist(address account) public onlyRole(COMPLIANCE_ROLE) {
        blacklist[account] = false;
        emit BlacklistUpdated(account, false);
    }

    function toggleWhitelist() public onlyRole(COMPLIANCE_ROLE) {
        whitelistEnabled = !whitelistEnabled;
        emit WhitelistToggled(whitelistEnabled);
    }

    function toggleTransferRestrictions() public onlyRole(COMPLIANCE_ROLE) {
        transferRestrictionsEnabled = !transferRestrictionsEnabled;
        emit TransferRestrictionsToggled(transferRestrictionsEnabled);
    }

    function setTransferLimit(address account, uint256 limit) public onlyRole(COMPLIANCE_ROLE) {
        transferLimits[account] = limit;
        emit TransferLimitSet(account, limit);
    }

    function toggleTransferLimits() public onlyRole(COMPLIANCE_ROLE) {
        transferLimitsEnabled = !transferLimitsEnabled;
        emit TransferLimitsToggled(transferLimitsEnabled);
    }

    // Asset management functions
    function updateValuation(uint256 newValuation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(RWALibrary.isValidValuation(newValuation), "RWAToken: invalid valuation");
        uint256 oldValuation = assetInfo.valuation;
        assetInfo.valuation = newValuation;
        emit AssetValuationUpdated(oldValuation, newValuation, block.timestamp);
    }

    function updateValuationFromOracle() public onlyRole(ORACLE_ROLE) {
        require(address(oracle) != address(0), "RWAToken: oracle not set");
        uint256 oraclePrice = oracle.getLatestPrice();
        require(oraclePrice > 0, "RWAToken: invalid oracle price");
        require(RWALibrary.isValidValuation(oraclePrice), "RWAToken: invalid valuation");
        uint256 oldValuation = assetInfo.valuation;
        assetInfo.valuation = oraclePrice;
        emit AssetValuationUpdated(oldValuation, oraclePrice, block.timestamp);
    }

    function updateDescription(string memory newDescription) public onlyRole(DEFAULT_ADMIN_ROLE) {
        assetInfo.description = newDescription;
    }

    function deactivateAsset() public onlyRole(DEFAULT_ADMIN_ROLE) {
        assetInfo.isActive = false;
    }

    function activateAsset() public onlyRole(DEFAULT_ADMIN_ROLE) {
        assetInfo.isActive = true;
    }

    // Integration functions
    function setOracle(address oracleAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address oldOracle = address(oracle);
        oracle = IOracle(oracleAddress);
        emit OracleUpdated(oldOracle, oracleAddress);
    }

    function setKYCProvider(address providerAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address oldProvider = address(kycProvider);
        kycProvider = IKYCProvider(providerAddress);
        emit KYCProviderUpdated(oldProvider, providerAddress);
    }

    function toggleKYCRequired() public onlyRole(COMPLIANCE_ROLE) {
        kycRequired = !kycRequired;
        emit KYCRequiredToggled(kycRequired);
    }

    function setFeeManager(address feeManagerAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address oldFeeManager = feeManager;
        feeManager = feeManagerAddress;
        emit FeeManagerUpdated(oldFeeManager, feeManagerAddress);
    }

    function setVestingContract(address vestingAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address oldContract = vestingContract;
        vestingContract = vestingAddress;
        emit VestingContractUpdated(oldContract, vestingAddress);
    }

    function setDividendContract(address dividendAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address oldContract = dividendContract;
        dividendContract = dividendAddress;
        emit DividendContractUpdated(oldContract, dividendAddress);
    }

    // Redemption functions
    function toggleRedemption() public onlyRole(DEFAULT_ADMIN_ROLE) {
        redemptionEnabled = !redemptionEnabled;
        emit RedemptionToggled(redemptionEnabled);
    }

    function setRedemptionToken(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        redemptionToken = IERC20(tokenAddress);
    }

    function setRedemptionFee(uint256 fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(fee <= 1000, "RWAToken: fee cannot exceed 10%");
        redemptionFee = fee;
    }

    // Custody functions
    function updateCustodian(address newCustodian) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newCustodian != address(0), "RWAToken: custodian cannot be zero address");
        address oldCustodian = assetInfo.custodian;
        _revokeRole(CUSTODIAN_ROLE, oldCustodian);
        _grantRole(CUSTODIAN_ROLE, newCustodian);
        assetInfo.custodian = newCustodian;
        emit CustodianUpdated(oldCustodian, newCustodian);
    }

    // Document management
    function addDocument(string memory documentType, string memory documentHash) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bytes(documentHash).length > 0, "RWAToken: document hash cannot be empty");
        if (bytes(documents[documentType]).length == 0) {
            documentTypes.push(documentType);
        }
        documents[documentType] = documentHash;
        emit DocumentAdded(documentType, documentHash);
    }

    function updateDocument(string memory documentType, string memory newHash) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bytes(documents[documentType]).length > 0, "RWAToken: document does not exist");
        string memory oldHash = documents[documentType];
        documents[documentType] = newHash;
        emit DocumentUpdated(documentType, oldHash, newHash);
    }

    function getDocument(string memory documentType) public view returns (string memory) {
        return documents[documentType];
    }

    function getDocumentTypes() public view returns (string[] memory) {
        return documentTypes;
    }

    // View functions
    function getAssetInfo() public view override returns (AssetInfo memory) {
        return assetInfo;
    }

    function getTokenPrice() public view override returns (uint256) {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) {
            return 0;
        }
        uint256 currentValuation = assetInfo.valuation;
        if (address(oracle) != address(0)) {
            try oracle.getLatestPrice() returns (uint256 oraclePrice) {
                if (oraclePrice > 0) {
                    currentValuation = oraclePrice;
                }
            } catch {}
        }
        return (currentValuation * 1e18) / totalSupply;
    }

    function canTransfer(address from, address to) public view override returns (bool) {
        if (!assetInfo.isActive) return false;
        if (paused()) return false;
        
        if (kycRequired && address(kycProvider) != address(0)) {
            if (from != address(0) && !kycProvider.isKYCVerified(from)) return false;
            if (to != address(0) && !kycProvider.isKYCVerified(to)) return false;
        }
        
        if (transferRestrictionsEnabled) {
            if (blacklist[from] || blacklist[to]) return false;
            if (whitelistEnabled) {
                if (!whitelist[from] && from != address(0)) return false;
                if (!whitelist[to] && to != address(0)) return false;
            }
        }
        
        return true;
    }

    function getOwnershipPercentage(address account) public view returns (uint256) {
        return RWALibrary.calculateOwnershipPercentage(balanceOf(account), totalSupply());
    }

    function getAssetValue(address account) public view returns (uint256) {
        return RWALibrary.calculateAssetValue(balanceOf(account), totalSupply(), assetInfo.valuation);
    }

    function getRedemptionValue(uint256 tokenAmount) public view returns (uint256) {
        return _calculateRedemptionValue(tokenAmount);
    }
}
