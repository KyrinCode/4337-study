// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";

uint256 constant MODULE_TYPE_VALIDATOR = 1;
uint256 constant MODULE_TYPE_EXECUTOR = 2;
uint256 constant MODULE_TYPE_FALLBACK = 3;
uint256 constant MODULE_TYPE_HOOK = 4;
uint256 constant MODULE_TYPE_STATELESS_VALIDATOR = 7;

interface IModule {
    /**
     * @dev This function is called by the smart account during installation of the module
     * @param data arbitrary data that may be required on the module during `onInstall` initialization
     *
     * MUST revert on error (e.g. if module is already enabled)
     */
    function onInstall(bytes calldata data) external;

    /**
     * @dev This function is called by the smart account during uninstallation of the module
     * @param data arbitrary data that may be required on the module during `onUninstall` de-initialization
     *
     * MUST revert on error
     */
    function onUninstall(bytes calldata data) external;

    /**
     * @dev Returns boolean value if module is a certain type
     * @param moduleTypeId the module type ID according the ERC-7579 spec
     *
     * MUST return true if the module is of the given type and false otherwise
     */
    function isModuleType(uint256 moduleTypeId) external view returns (bool);
}

interface IHook is IModule {
    /**
     * @dev Called by the smart account before execution
     * @param msgSender the address that called the smart account
     * @param value the value that was sent to the smart account
     * @param msgData the data that was sent to the smart account
     *
     * MAY return arbitrary data in the `hookData` return value
     */
    function preCheck(
        address msgSender,
        uint256 value,
        bytes calldata msgData
    ) external returns (bytes memory hookData);

    /**
     * @dev Called by the smart account after execution
     * @param hookData the data that was returned by the `preCheck` function
     *
     * MAY validate the `hookData` to validate transaction context of the `preCheck` function
     */
    function postCheck(bytes calldata hookData) external;
}

interface IValidator is IModule {
    /**
     * @dev Validates a UserOperation
     * @param userOp the ERC-4337 PackedUserOperation
     * @param userOpHash the hash of the ERC-4337 PackedUserOperation
     *
     * MUST validate that the signature is a valid signature of the userOpHash
     * SHOULD return ERC-4337's SIG_VALIDATION_FAILED (and not revert) on signature mismatch
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns (uint256);

    /**
     * @dev Validates a signature using ERC-1271
     * @param sender the address that sent the ERC-1271 request to the smart account
     * @param hash the hash of the ERC-1271 request
     * @param signature the signature of the ERC-1271 request
     *
     * MUST return the ERC-1271 `MAGIC_VALUE` if the signature is valid
     * MUST NOT modify state
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata signature
    ) external view returns (bytes4);
}

interface IStatelessValidator {
    /**
     * @dev Validates a signature given some data
     * @param hash The data that was signed over
     * @param signature The signature to verify
     * @param data The data to validate the verified signature agains
     *
     * MUST validate that the signature is a valid signature of the hash
     * MUST compare the validated signature against the data provided
     * MUST return true if the signature is valid and false otherwise
     */
    function validateSignatureWithData(
        bytes32 hash,
        bytes calldata signature,
        bytes calldata data
    ) external view returns (bool);

    /**
     * @dev Returns boolean value if module is a certain type
     * @param moduleTypeId the module type ID according the ERC-7579 spec
     *
     * MUST return true if the module is of the given type and false otherwise
     */
    function isModuleType(uint256 moduleTypeId) external view returns (bool);
}
