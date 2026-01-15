// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RWAVesting
 * @dev Vesting schedule contract for RWA tokens
 */
contract RWAVesting is AccessControl {
    bytes32 public constant VESTING_ADMIN_ROLE = keccak256("VESTING_ADMIN_ROLE");

    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliff;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    mapping(address => VestingSchedule[]) public vestingSchedules;
    mapping(address => uint256) public totalVested;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliff
    );
    event TokensReleased(address indexed beneficiary, uint256 indexed scheduleId, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 indexed scheduleId);

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "RWAVesting: token cannot be zero address");
        token = IERC20(tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VESTING_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Create a vesting schedule
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliff,
        bool revocable
    ) external onlyRole(VESTING_ADMIN_ROLE) returns (uint256) {
        require(beneficiary != address(0), "RWAVesting: beneficiary cannot be zero address");
        require(totalAmount > 0, "RWAVesting: total amount must be greater than zero");
        require(duration > 0, "RWAVesting: duration must be greater than zero");
        require(cliff <= duration, "RWAVesting: cliff cannot exceed duration");
        require(startTime >= block.timestamp, "RWAVesting: start time must be in the future");

        uint256 scheduleId = vestingSchedules[beneficiary].length;
        vestingSchedules[beneficiary].push(
            VestingSchedule({
                beneficiary: beneficiary,
                totalAmount: totalAmount,
                releasedAmount: 0,
                startTime: startTime,
                duration: duration,
                cliff: cliff,
                revocable: revocable,
                revoked: false
            })
        );

        totalVested[beneficiary] += totalAmount;
        require(
            token.transferFrom(msg.sender, address(this), totalAmount),
            "RWAVesting: token transfer failed"
        );

        emit VestingScheduleCreated(beneficiary, scheduleId, totalAmount, startTime, duration, cliff);
        return scheduleId;
    }

    /**
     * @dev Release vested tokens
     */
    function release(address beneficiary, uint256 scheduleId) external {
        VestingSchedule storage schedule = vestingSchedules[beneficiary][scheduleId];
        require(schedule.beneficiary == beneficiary, "RWAVesting: invalid beneficiary");
        require(!schedule.revoked, "RWAVesting: schedule is revoked");

        uint256 releasable = _releasableAmount(schedule);
        require(releasable > 0, "RWAVesting: no tokens to release");

        schedule.releasedAmount += releasable;
        totalVested[beneficiary] -= releasable;

        require(token.transfer(beneficiary, releasable), "RWAVesting: token transfer failed");
        emit TokensReleased(beneficiary, scheduleId, releasable);
    }

    /**
     * @dev Revoke a vesting schedule
     */
    function revoke(address beneficiary, uint256 scheduleId) external onlyRole(VESTING_ADMIN_ROLE) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary][scheduleId];
        require(schedule.revocable, "RWAVesting: schedule is not revocable");
        require(!schedule.revoked, "RWAVesting: schedule already revoked");

        schedule.revoked = true;
        uint256 unreleased = schedule.totalAmount - schedule.releasedAmount;
        totalVested[beneficiary] -= unreleased;

        require(token.transfer(msg.sender, unreleased), "RWAVesting: token transfer failed");
        emit VestingRevoked(beneficiary, scheduleId);
    }

    /**
     * @dev Get releasable amount for a schedule
     */
    function getReleasableAmount(address beneficiary, uint256 scheduleId) external view returns (uint256) {
        return _releasableAmount(vestingSchedules[beneficiary][scheduleId]);
    }

    /**
     * @dev Get vesting schedule details
     */
    function getVestingSchedule(address beneficiary, uint256 scheduleId) external view returns (VestingSchedule memory) {
        return vestingSchedules[beneficiary][scheduleId];
    }

    function _releasableAmount(VestingSchedule memory schedule) private view returns (uint256) {
        if (schedule.revoked) return 0;
        if (block.timestamp < schedule.startTime + schedule.cliff) return 0;
        if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount - schedule.releasedAmount;
        }

        uint256 elapsed = block.timestamp - schedule.startTime;
        uint256 vested = (schedule.totalAmount * elapsed) / schedule.duration;
        if (vested > schedule.totalAmount) vested = schedule.totalAmount;
        return vested - schedule.releasedAmount;
    }
}
