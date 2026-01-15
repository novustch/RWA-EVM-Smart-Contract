// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IRWAToken.sol";
import "./libraries/RWALibrary.sol";

/**
 * @title RWADividend
 * @dev Dividend distribution contract for RWA token holders
 */
contract RWADividend is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    IRWAToken public immutable rwaToken;
    IERC20 public immutable paymentToken; // USDC, DAI, etc.

    struct DividendPeriod {
        uint256 periodId;
        uint256 totalAmount;
        uint256 distributedAmount;
        uint256 snapshotBlock;
        uint256 distributionDate;
        bool isActive;
        mapping(address => bool) claimed;
    }

    mapping(uint256 => DividendPeriod) public dividendPeriods;
    uint256 public currentPeriodId;
    uint256 public totalDividendsDistributed;

    event DividendPeriodCreated(uint256 indexed periodId, uint256 totalAmount, uint256 snapshotBlock);
    event DividendClaimed(address indexed claimer, uint256 indexed periodId, uint256 amount);
    event DividendDistributed(uint256 indexed periodId, uint256 totalAmount);

    constructor(address rwaTokenAddress, address paymentTokenAddress) {
        require(rwaTokenAddress != address(0), "RWADividend: RWA token cannot be zero address");
        require(paymentTokenAddress != address(0), "RWADividend: payment token cannot be zero address");
        
        rwaToken = IRWAToken(rwaTokenAddress);
        paymentToken = IERC20(paymentTokenAddress);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
    }

    /**
     * @dev Create a new dividend period
     */
    function createDividendPeriod(uint256 totalAmount) external onlyRole(DISTRIBUTOR_ROLE) returns (uint256) {
        require(totalAmount > 0, "RWADividend: amount must be greater than zero");
        
        paymentToken.safeTransferFrom(msg.sender, address(this), totalAmount);
        
        currentPeriodId++;
        DividendPeriod storage period = dividendPeriods[currentPeriodId];
        period.periodId = currentPeriodId;
        period.totalAmount = totalAmount;
        period.snapshotBlock = block.number;
        period.distributionDate = block.timestamp;
        period.isActive = true;

        emit DividendPeriodCreated(currentPeriodId, totalAmount, block.number);
        return currentPeriodId;
    }

    /**
     * @dev Claim dividends for a specific period
     */
    function claimDividend(uint256 periodId) external {
        DividendPeriod storage period = dividendPeriods[periodId];
        require(period.isActive, "RWADividend: period is not active");
        require(!period.claimed[msg.sender], "RWADividend: already claimed");

        uint256 balance = rwaToken.balanceOf(msg.sender);
        require(balance > 0, "RWADividend: no tokens to claim dividend");

        // Get balance at snapshot block
        uint256 snapshotBalance = _getBalanceAtBlock(msg.sender, period.snapshotBlock);
        require(snapshotBalance > 0, "RWADividend: no balance at snapshot");

        uint256 dividend = RWALibrary.calculateDividend(
            snapshotBalance,
            rwaToken.totalSupply(),
            period.totalAmount
        );

        require(dividend > 0, "RWADividend: no dividend to claim");
        require(period.distributedAmount + dividend <= period.totalAmount, "RWADividend: insufficient funds");

        period.claimed[msg.sender] = true;
        period.distributedAmount += dividend;
        totalDividendsDistributed += dividend;

        paymentToken.safeTransfer(msg.sender, dividend);
        emit DividendClaimed(msg.sender, periodId, dividend);
    }

    /**
     * @dev Get claimable dividend for a user
     */
    function getClaimableDividend(address account, uint256 periodId) external view returns (uint256) {
        DividendPeriod storage period = dividendPeriods[periodId];
        if (!period.isActive || period.claimed[account]) return 0;

        uint256 snapshotBalance = _getBalanceAtBlock(account, period.snapshotBlock);
        if (snapshotBalance == 0) return 0;

        return RWALibrary.calculateDividend(
            snapshotBalance,
            rwaToken.totalSupply(),
            period.totalAmount
        );
    }

    /**
     * @dev Close a dividend period
     */
    function closeDividendPeriod(uint256 periodId) external onlyRole(DISTRIBUTOR_ROLE) {
        DividendPeriod storage period = dividendPeriods[periodId];
        require(period.isActive, "RWADividend: period already closed");
        
        period.isActive = false;
        uint256 remaining = period.totalAmount - period.distributedAmount;
        
        if (remaining > 0) {
            paymentToken.safeTransfer(msg.sender, remaining);
        }
    }

    function _getBalanceAtBlock(address account, uint256 blockNumber) private view returns (uint256) {
        // This is a simplified version. In production, you'd use a snapshot mechanism
        // For now, we'll use current balance as a proxy
        // In a real implementation, you'd use a library like OpenZeppelin's ERC20Snapshot
        return rwaToken.balanceOf(account);
    }
}
