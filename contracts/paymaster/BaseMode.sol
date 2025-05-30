// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "@account-abstraction/contracts/core/UserOperationLib.sol";
import "../interfaces/IConfig.sol";
import "./interfaces/IBasePaymaster.sol";
import "../utils/Errors.sol";

/**
 * @title BaseMode
 * @notice Base contract for paymaster implementations
 * @dev Implements basic paymaster functionality and gas management
 */
contract BaseMode is Ownable, IBasePaymaster {
    using UserOperationLib for PackedUserOperation;
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    uint256 public constant SIG_VALIDATION_FAILED = 1;
    IConfig public immutable CONFIG;
    address public immutable ENTRYPOINT;
    address public immutable ADDRESS_THIS = address(this);

    /**
     * @notice Validates that the caller is the supported EntryPoint
     * @param _entrypoint The address to validate
     */
    modifier validEntryPoint(address _entrypoint) {
        if (_entrypoint != ENTRYPOINT)
            revert NotFromSupportedEntryPoint(_entrypoint);
        _;
    }

    /**
     * @notice Allows the contract to receive ETH
     */
    receive() external payable virtual {}

    /**
     * @notice Initializes the contract with required addresses
     * @param _owner The address that will own this contract
     * @param _entryPoint The EntryPoint contract address
     * @param _config The configuration contract address
     */
    constructor(
        address _owner,
        address _entryPoint,
        address _config
    ) Ownable(_owner) {
        ENTRYPOINT = _entryPoint;
        CONFIG = IConfig(_config);
    }

    /**
     * @notice Deposits gas to the EntryPoint contract
     * @dev Deposits gas to an EntryPoint.
     * @param amount The amount of gas to deposit
     */
    function depositGas(uint256 amount) internal {
        IEntryPoint(ENTRYPOINT).depositTo{value: amount}(ADDRESS_THIS);
    }

    /**
     * @notice Withdraws gas from the EntryPoint contract
     * @dev Withdraws gas from an EntryPoint. Withdraw all gas may pause the contract.
     * @param recipient The address to receive the withdrawn gas
     * @param amount The amount of gas to withdraw
     */
    function withdrawGas(
        address payable recipient,
        uint256 amount
    ) external onlyOwner {
        IEntryPoint(ENTRYPOINT).withdrawTo(recipient, amount);
    }

    /**
     * @notice Checks if the transaction originator is a whitelisted bundler
     * @return bool True if the bundler is whitelisted, false otherwise
     */
    function _isWhitelistedBundler() internal view returns (bool) {
        return CONFIG.isWhitelistedBundler(tx.origin);
    }

    /**
     * @notice Validates a paymaster user operation
     * @param userOp The user operation to validate
     * @param userOpHash The hash of the user operation
     * @param requiredPreFund The required pre-fund amount
     * @return bytes Memory buffer for context
     * @return uint256 Validation result (0 for success, 1 for failure)
     */
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 requiredPreFund
    ) external view virtual returns (bytes memory, uint256) {}

    /**
     * @notice Handles post-operation processing
     * @dev Virtual implementation of the postOp function from IPaymaster.
     * @param postOpMode The mode of the post-operation
     * @param context The context data from the validation phase
     * @param actualGasCost The actual gas cost of the operation
     * @param actualUserOpFeePerGas The actual fee per gas for the operation
     */
    function postOp(
        IPaymaster.PostOpMode postOpMode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external virtual {
        // Default implementation (can be overridden)
    }
}
