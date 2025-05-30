// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

/// @title Interface for managing DKIM keys and their associated domains
/// @notice Provides functionality to update and remove DKIM keys and retrieve domain information
interface IDkimKeyOracle {
    /// @notice Emitted when the pauser address is updated
    /// @param pauser The new pauser address
    event PauserUpdated(address pauser);

    /// @notice Emitted when a DKIM key is updated with its associated domain
    /// @param keyHash The hash of the DKIM key
    /// @param domainHash The hash of the associated domain
    event DkimKeyUpdated(bytes32 keyHash, bytes32 domainHash);

    /// @notice Emitted when a DKIM key is removed
    /// @param keyHash The hash of the removed DKIM key
    event DkimKeyRemoved(bytes32 keyHash);

    /// @notice Updates a DKIM key with its associated domain
    /// @param _keyHash The hash of the DKIM key to update
    /// @param _domain The hash of the domain to associate with the key
    function updateKey(bytes32 _keyHash, bytes32 _domain) external;

    /// @notice Removes a DKIM key
    /// @param _keyHash The hash of the DKIM key to remove
    function removeKey(bytes32 _keyHash) external;

    /// @notice Retrieves the domain hash associated with a DKIM key
    /// @param _keyHash The hash of the DKIM key to query
    /// @return The hash of the domain associated with the key
    function getDomainHash(bytes32 _keyHash) external view returns (bytes32);
}
