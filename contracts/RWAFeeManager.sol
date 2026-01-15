// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title RWAFeeManager
 * @dev Fee management system for RWA operations
 */
contract RWAFeeManager is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant FEE_ADMIN_ROLE = keccak256("FEE_ADMIN_ROLE");

    struct FeeConfig {
        uint256 transferFee;        // Fee for transfers (basis points, 100 = 1%)
        uint256 mintFee;            // Fee for minting (basis points)
        uint256 redemptionFee;      // Fee for redemption (basis points)
        address feeRecipient;       // Address to receive fees
        IERC20 feeToken;            // Token to collect fees in (address(0) for native)
    }

    FeeConfig public feeConfig;
    uint256 public constant MAX_FEE = 1000; // 10% maximum fee
    uint256 public constant BASIS_POINTS = 10000;

    mapping(address => bool) public feeExempt; // Addresses exempt from fees

    event FeeConfigUpdated(
        uint256 transferFee,
        uint256 mintFee,
        uint256 redemptionFee,
        address feeRecipient
    );
    event FeeCollected(address indexed payer, uint256 amount, string feeType);
    event FeeExemptUpdated(address indexed account, bool exempt);

    constructor(address feeRecipient) {
        require(feeRecipient != address(0), "RWAFeeManager: fee recipient cannot be zero address");
        
        feeConfig = FeeConfig({
            transferFee: 0,
            mintFee: 0,
            redemptionFee: 0,
            feeRecipient: feeRecipient,
            feeToken: IERC20(address(0)) // Native token by default
        });

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FEE_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Calculate fee for an amount
     */
    function calculateFee(uint256 amount, string memory feeType) public view returns (uint256) {
        uint256 feeRate;
        
        if (keccak256(bytes(feeType)) == keccak256(bytes("transfer"))) {
            feeRate = feeConfig.transferFee;
        } else if (keccak256(bytes(feeType)) == keccak256(bytes("mint"))) {
            feeRate = feeConfig.mintFee;
        } else if (keccak256(bytes(feeType)) == keccak256(bytes("redemption"))) {
            feeRate = feeConfig.redemptionFee;
        } else {
            return 0;
        }

        return (amount * feeRate) / BASIS_POINTS;
    }

    /**
     * @dev Collect fee
     */
    function collectFee(address payer, uint256 amount, string memory feeType) external returns (uint256) {
        if (feeExempt[payer]) return 0;
        
        uint256 fee = calculateFee(amount, feeType);
        if (fee == 0) return 0;

        if (address(feeConfig.feeToken) == address(0)) {
            // Native token
            require(msg.value >= fee, "RWAFeeManager: insufficient fee payment");
            (bool success, ) = feeConfig.feeRecipient.call{value: fee}("");
            require(success, "RWAFeeManager: fee transfer failed");
        } else {
            // ERC20 token
            feeConfig.feeToken.safeTransferFrom(payer, feeConfig.feeRecipient, fee);
        }

        emit FeeCollected(payer, fee, feeType);
        return fee;
    }

    /**
     * @dev Update fee configuration
     */
    function updateFeeConfig(
        uint256 transferFee,
        uint256 mintFee,
        uint256 redemptionFee,
        address feeRecipient,
        address feeToken
    ) external onlyRole(FEE_ADMIN_ROLE) {
        require(transferFee <= MAX_FEE, "RWAFeeManager: transfer fee too high");
        require(mintFee <= MAX_FEE, "RWAFeeManager: mint fee too high");
        require(redemptionFee <= MAX_FEE, "RWAFeeManager: redemption fee too high");
        require(feeRecipient != address(0), "RWAFeeManager: fee recipient cannot be zero address");

        feeConfig.transferFee = transferFee;
        feeConfig.mintFee = mintFee;
        feeConfig.redemptionFee = redemptionFee;
        feeConfig.feeRecipient = feeRecipient;
        feeConfig.feeToken = IERC20(feeToken);

        emit FeeConfigUpdated(transferFee, mintFee, redemptionFee, feeRecipient);
    }

    /**
     * @dev Set fee exemption status
     */
    function setFeeExempt(address account, bool exempt) external onlyRole(FEE_ADMIN_ROLE) {
        feeExempt[account] = exempt;
        emit FeeExemptUpdated(account, exempt);
    }
}
