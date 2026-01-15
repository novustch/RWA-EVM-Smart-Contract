// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IKYCProvider
 * @dev Interface for KYC/AML provider integration
 */
interface IKYCProvider {
    function isKYCVerified(address account) external view returns (bool);
    function isAMLVerified(address account) external view returns (bool);
    function getKYCLevel(address account) external view returns (uint8);
}
