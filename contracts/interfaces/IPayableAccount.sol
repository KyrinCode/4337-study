// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import {IExecution, IAccountConfig, IModuleConfig} from "./IERC7579Account.sol";

/// @title Interface for payable smart contract accounts with recovery and module management
/// @notice Defines the interface for accounts that can receive payments and manage modules
interface IPayableAccount is IExecution, IAccountConfig, IModuleConfig {
    /// @notice Emitted when an account is recovered using a validator
    /// @param validator The address of the validator used for recovery
    /// @param subject The data associated with the recovery
    event AccountRecovered(address validator, bytes subject);

    /// @notice Emitted when a module is installed with additional data
    /// @param typeId The type identifier of the installed module
    /// @param module The address of the installed module
    /// @param data Additional data used during installation
    event ModuleInstalledWithData(uint256 typeId, address module, bytes data);

    /// @notice Emitted when a module is uninstalled with additional data
    /// @param typeId The type identifier of the uninstalled module
    /// @param module The address of the uninstalled module
    /// @param data Additional data used during uninstallation
    event ModuleUninstalledWithData(uint256 typeId, address module, bytes data);

    /// @notice Emitted when a recovery module is installed
    /// @param recoveryModule The address of the installed recovery module
    event RecoveryModuleInstalled(address recoveryModule);

    /// @notice Emitted when a recovery module is uninstalled
    /// @param recoveryModule The address of the uninstalled recovery module
    event RecoveryModuleUninstalled(address recoveryModule);

    /// @notice Emitted when a recovery fee is claimed
    /// @param to The address receiving the recovery fee
    /// @param amount The amount of the recovery fee claimed
    event RecoveryFeeClaimed(address to, uint256 amount);

    /// @notice Emitted when the account receives a payment
    /// @param sender The address sending the payment
    /// @param value The amount of the payment
    event SafeReceived(address sender, uint256 value);

    /// @notice Error thrown when recovery fee payment fails
    /// @param receiver The intended receiver of the fee
    /// @param value The amount that failed to transfer
    error RecoveryFeePaymentFailed(address receiver, uint256 value);

    /// @notice Error thrown when recovery attempt is made with expired validation times
    /// @param oldValidFrom The previous validation timestamp
    /// @param newValidFrom The new validation timestamp
    error RecoveryExpired(uint128 oldValidFrom, uint128 newValidFrom);

    /// @notice Error thrown when there is an issue with the passkey
    error PassKeyError();

    /// @notice Initializes the account with provided data
    /// @param data The initialization data
    function initialize(bytes calldata data) external;

    /// @notice Recovers the account using a validator and associated data
    /// @param validator The address of the validator
    /// @param data The recovery data
    function recover(address validator, bytes calldata data) external;

    /// @notice Claims the recovery fee
    /// @param receiver The address to receive the fee
    /// @param value The amount to be claimed
    function claimRecoveryFee(address receiver, uint256 value) external;

    /// @notice Installs a recovery module
    /// @param recoveryModule The address of the recovery module to install
    /// @param data Additional data for installation
    function installRecoveryModule(
        address recoveryModule,
        bytes calldata data
    ) external;

    /// @notice Uninstalls a recovery module
    /// @param recoveryModule The address of the recovery module to uninstall
    /// @param data Additional data for uninstallation
    function uninstallRecoveryModule(
        address recoveryModule,
        bytes calldata data
    ) external;

    /// @notice Installs a module of specified type
    /// @param typeId The type identifier of the module
    /// @param module The address of the module to install
    /// @param data Additional data for installation
    function installModule(
        uint256 typeId,
        address module,
        bytes calldata data
    ) external;

    /// @notice Uninstalls a module of specified type
    /// @param typeId The type identifier of the module
    /// @param module The address of the module to uninstall
    /// @param data Additional data for uninstallation
    function uninstallModule(
        uint256 typeId,
        address module,
        bytes calldata data
    ) external;

    /// @notice Validates a signature for a given hash
    /// @dev Implements EIP-1271 signature validation
    /// @param _hash The hash to validate
    /// @param _signature The signature to validate
    /// @return bytes4 The function selector if valid, or 0xffffffff if invalid
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4);
}
