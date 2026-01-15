// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOracle
 * @dev Interface for price oracle integration
 */
interface IOracle {
    function getLatestPrice() external view returns (uint256);
    function getPriceTimestamp() external view returns (uint256);
    function updatePrice(uint256 newPrice) external;
}
