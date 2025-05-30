// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IDkimKeyOracle} from "../interfaces/IDkimKeyOracle.sol";

/**
 * @title DkimKeyOracle
 * @dev A contract for managing DKIM public key hashes and their associated email domain hashes.
 * @notice This contract implements the IDkimKeyOracle interface and inherits from Ownable.
 */
contract DkimKeyOracle is IDkimKeyOracle, Ownable {
    error AccessDenied();

    // dkimPublicKeyHash -> emailDomainHash
    mapping(bytes32 => bytes32) public getDomainHash;

    /** @dev Address of the account with pauser privileges */
    address public pauser;

    /**
     * @dev Constructor to set up the contract
     * @param _owner Address of the contract owner
     * @param _pauser Address of the account with pauser privileges
     */
    constructor(address _owner, address _pauser) Ownable(_owner) {
        pauser = _pauser;
    }

    /**
     * @dev Modifier to restrict access to the pauser
     */
    modifier onlyPauser() {
        if (msg.sender != pauser) revert AccessDenied();
        _;
    }

    /**
     * Updates the pauser address
     * @param _pauser New pauser address
     */
    function updatePauser(address _pauser) external onlyOwner {
        pauser = _pauser;
        emit PauserUpdated(_pauser);
    }

    /**
     * @dev Updates or adds a DKIM key hash and its associated domain hash
     * @param _keyHash The DKIM public key hash
     * @param _domain The associated email domain hash
     */
    function updateKey(bytes32 _keyHash, bytes32 _domain) external onlyOwner {
        getDomainHash[_keyHash] = _domain;
        emit DkimKeyUpdated(_keyHash, _domain);
    }

    /**
     * @dev Removes a DKIM key hash and its associated domain hash
     * @param _keyHash The DKIM public key hash to remove
     */
    function removeKey(bytes32 _keyHash) external onlyPauser {
        delete getDomainHash[_keyHash];
        emit DkimKeyRemoved(_keyHash);
    }
}
