// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import {IRecoveryModule} from "./IRecoveryModule.sol";

/**
 * @title Email Recovery Module Interface
 * @notice Interface for email-based account recovery functionality
 * @dev Extends IRecoveryModule with email-specific recovery methods
 */
interface IEmailRecoveryModule is IRecoveryModule {
    /**
     * @notice Emitted when a new signer is set
     * @param newSigner Address of the new signer
     */
    event SignerUpdated(address newSigner);

    /**
     * @notice Emitted when a new oracle is set
     * @param newOracle Address of the new oracle
     */
    event OracleUpdated(address newOracle);

    /**
     * @notice Emitted when an account's email hash is updated
     * @param account Address of the account
     * @param emailHash New email hash
     * @param updatedAt Timestamp of the update
     */
    event EmailHashUpdated(
        address account,
        bytes32 emailHash,
        uint256 updatedAt
    );

    /**
     * @notice Thrown when account nonce is invalid
     */
    error InvalidAccountNonce();

    /**
     * @notice Thrown when signer is invalid
     */
    error InvalidSigner();

    /**
     * @notice Thrown when recovery proof is invalid
     */
    error InvalidProof();

    /**
     * @notice Thrown when recovering account address is invalid
     * @param sender Address attempting recovery
     * @param recoveringAccount Address being recovered
     */
    error InvalidRecoveringAccount(address sender, address recoveringAccount);

    /**
     * @notice Thrown when provided address is invalid
     */
    error InvalidAddress();

    /**
     * @notice Thrown when provided email hash is invalid
     */
    error InvalidEmailHash();

    /**
     * @notice Thrown when provided DKIM key hash is invalid
     */
    error InvalidDkimKeyHash();

    /**
     * @notice Gets the current oracle address
     * @return Address of the oracle
     */
    function getOracle() external view returns (address);

    /**
     * @notice Sets a new oracle address
     * @dev Only callable by authorized roles
     * @param _newOracle Address of the new oracle
     */
    function setOracle(address _newOracle) external;

    /**
     * @notice Gets the email hash and last update timestamp for an account
     * @param _account Address of the account
     * @return _hash The email hash
     * @return _lastUpdatedAt Timestamp of last update
     */
    function getEmailHash(
        address _account
    ) external view returns (bytes32 _hash, uint256 _lastUpdatedAt);

    /**
     * @notice Updates the email hash for the caller's account
     * @param _emailHash New email hash to set
     */
    function updateEmailHash(bytes32 _emailHash) external;
}
