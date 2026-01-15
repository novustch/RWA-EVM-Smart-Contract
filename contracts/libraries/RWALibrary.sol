// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RWALibrary
 * @dev Library for RWA-related calculations and utilities
 */
library RWALibrary {
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_VALUATION = type(uint256).max / PRECISION;

    /**
     * @dev Calculate ownership percentage
     * @param balance Token balance
     * @param totalSupply Total token supply
     * @return percentage Ownership percentage (scaled by 1e18)
     */
    function calculateOwnershipPercentage(
        uint256 balance,
        uint256 totalSupply
    ) internal pure returns (uint256) {
        if (totalSupply == 0) return 0;
        return (balance * PRECISION) / totalSupply;
    }

    /**
     * @dev Calculate asset value for a token holder
     * @param balance Token balance
     * @param totalSupply Total token supply
     * @param assetValuation Total asset valuation
     * @return value Asset value owned by holder (scaled by 1e18)
     */
    function calculateAssetValue(
        uint256 balance,
        uint256 totalSupply,
        uint256 assetValuation
    ) internal pure returns (uint256) {
        if (totalSupply == 0) return 0;
        return (balance * assetValuation) / totalSupply;
    }

    /**
     * @dev Calculate dividend amount for a holder
     * @param balance Token balance
     * @param totalSupply Total token supply
     * @param totalDividend Total dividend to distribute
     * @return dividend Dividend amount for holder
     */
    function calculateDividend(
        uint256 balance,
        uint256 totalSupply,
        uint256 totalDividend
    ) internal pure returns (uint256) {
        if (totalSupply == 0) return 0;
        return (balance * totalDividend) / totalSupply;
    }

    /**
     * @dev Validate valuation is within reasonable bounds
     * @param valuation Asset valuation
     * @return bool Whether valuation is valid
     */
    function isValidValuation(uint256 valuation) internal pure returns (bool) {
        return valuation > 0 && valuation <= MAX_VALUATION;
    }
}
