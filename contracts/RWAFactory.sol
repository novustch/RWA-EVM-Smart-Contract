// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./RWAToken.sol";

/**
 * @title RWAFactory
 * @dev Factory contract for deploying RWA token contracts
 */
contract RWAFactory is AccessControl {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    struct TokenInfo {
        address tokenAddress;
        string assetType;
        string assetId;
        address owner;
        uint256 deploymentDate;
    }

    mapping(address => TokenInfo) public tokens;
    address[] public deployedTokens;
    uint256 public tokenCount;

    event TokenDeployed(
        address indexed tokenAddress,
        address indexed owner,
        string assetType,
        string assetId,
        uint256 deploymentDate
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEPLOYER_ROLE, msg.sender);
    }

    /**
     * @dev Deploy a new RWA token
     */
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
    ) external onlyRole(DEPLOYER_ROLE) returns (address) {
        RWAToken newToken = new RWAToken(
            name,
            symbol,
            initialOwner,
            assetType,
            assetId,
            description,
            valuation,
            custodian,
            documentHash
        );

        address tokenAddress = address(newToken);
        
        tokens[tokenAddress] = TokenInfo({
            tokenAddress: tokenAddress,
            assetType: assetType,
            assetId: assetId,
            owner: initialOwner,
            deploymentDate: block.timestamp
        });

        deployedTokens.push(tokenAddress);
        tokenCount++;

        emit TokenDeployed(tokenAddress, initialOwner, assetType, assetId, block.timestamp);
        return tokenAddress;
    }

    /**
     * @dev Get all deployed tokens
     */
    function getAllTokens() external view returns (address[] memory) {
        return deployedTokens;
    }

    /**
     * @dev Get token info
     */
    function getTokenInfo(address tokenAddress) external view returns (TokenInfo memory) {
        return tokens[tokenAddress];
    }

    /**
     * @dev Get token count
     */
    function getTokenCount() external view returns (uint256) {
        return tokenCount;
    }
}
