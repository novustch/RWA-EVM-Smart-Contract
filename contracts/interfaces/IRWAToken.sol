// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRWAToken
 * @dev Interface for RWA Token contract
 */
interface IRWAToken {
    struct AssetInfo {
        string assetType;
        string assetId;
        string description;
        uint256 valuation;
        uint256 tokenizationDate;
        bool isActive;
        address custodian;
        string documentHash;
    }

    function getAssetInfo() external view returns (AssetInfo memory);
    function getTokenPrice() external view returns (uint256);
    function canTransfer(address from, address to) external view returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
