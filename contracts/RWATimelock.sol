// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RWATimelock
 * @dev Time lock mechanism for critical operations
 */
contract RWATimelock is AccessControl {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;

    uint256 public delay;
    mapping(bytes32 => bool) public queued;

    event Queued(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event Cancelled(bytes32 indexed txHash);
    event Executed(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);

    constructor(uint256 initialDelay) {
        require(initialDelay >= MIN_DELAY && initialDelay <= MAX_DELAY, "RWATimelock: invalid delay");
        delay = initialDelay;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
    }

    /**
     * @dev Queue a transaction
     */
    function queue(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyRole(PROPOSER_ROLE) returns (bytes32) {
        require(eta >= block.timestamp + delay, "RWATimelock: eta must be at least delay from now");
        
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(!queued[txHash], "RWATimelock: transaction already queued");
        
        queued[txHash] = true;
        emit Queued(txHash, target, value, signature, data, eta);
        return txHash;
    }

    /**
     * @dev Execute a queued transaction
     */
    function execute(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable onlyRole(EXECUTOR_ROLE) returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queued[txHash], "RWATimelock: transaction not queued");
        require(block.timestamp >= eta, "RWATimelock: transaction not ready");
        require(block.timestamp <= eta + 7 days, "RWATimelock: transaction stale");

        queued[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "RWATimelock: transaction execution reverted");

        emit Executed(txHash, target, value, signature, data, eta);
        return returnData;
    }

    /**
     * @dev Cancel a queued transaction
     */
    function cancel(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyRole(PROPOSER_ROLE) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queued[txHash], "RWATimelock: transaction not queued");
        
        queued[txHash] = false;
        emit Cancelled(txHash);
    }

    /**
     * @dev Update delay (only admin, with timelock)
     */
    function updateDelay(uint256 newDelay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newDelay >= MIN_DELAY && newDelay <= MAX_DELAY, "RWATimelock: invalid delay");
        delay = newDelay;
    }
}
