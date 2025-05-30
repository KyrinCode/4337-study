// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import "../utils/Errors.sol";
import {StructuredLinkedList} from "solidity-linked-list/contracts/StructuredLinkedList.sol";
import {IModule} from "../interfaces/IERC7579Module.sol";

/**
 * @title ValidationManager
 * @dev Manages validator sessions and their associated public keys
 */
contract ValidationManager {
    /**
     * @dev Represents a validation session with a validator address and time bounds
     * @param validator Address of the validator
     * @param validFrom Timestamp when the session becomes valid
     * @param validUntil Timestamp when the session expires
     */
    struct Session {
        address validator;
        uint128 validFrom;
        uint128 validUntil;
    }

    /** @dev Maximum number of public keys allowed per account */
    uint8 public constant MAXIMUM_KEYS_PER_ACCOUNT = 20;

    using StructuredLinkedList for StructuredLinkedList.List;

    /** @dev Linked list to store public key hashes */
    StructuredLinkedList.List internal pubKeyHashes;

    /** @dev Mapping of public key hash to validator session */
    mapping(bytes32 => Session) public validators;

    /**
     * @dev Installs a new validator with associated public key and time bounds
     * @param validator Address of the validator to install
     * @param data Encoded data containing public key hash, validFrom, and validUntil timestamps
     */
    function _installStatelessValidator(
        address validator,
        bytes memory data
    ) internal {
        if (pubKeyHashes.sizeOf() >= MAXIMUM_KEYS_PER_ACCOUNT)
            revert MaximumKeysExceeded();

        (bytes32 pubKeyHash, uint128 validFrom, uint128 validUntil) = abi
            .decode(data, (bytes32, uint128, uint128));
        uint256 node = uint256(pubKeyHash);
        if (node == 0) revert InvalidNode();
        validFrom = validFrom < block.timestamp
            ? uint128(block.timestamp)
            : validFrom;

        if (validUntil < validFrom) revert InvalidValidatorSession();

        Session memory session = Session(validator, validFrom, validUntil);

        if (!pubKeyHashes.nodeExists(node)) pubKeyHashes.pushFront(node);

        validators[pubKeyHash] = session;
    }

    /**
     * @dev Uninstalls a validator and removes its associated public key
     * @param validator Address of the validator to uninstall
     * @param data Encoded data containing public key hash
     */
    function _uninstallStatelessValidator(
        address validator,
        bytes calldata data
    ) internal {
        if (pubKeyHashes.sizeOf() == 1) revert RemovingLastKey();

        bytes32 pubKeyHash = abi.decode(data, (bytes32));

        if (validator != validators[pubKeyHash].validator)
            revert InvalidValidator();

        if (!pubKeyHashes.nodeExists(uint256(pubKeyHash)))
            revert InvalidPubKey();

        pubKeyHashes.remove(uint256(pubKeyHash));
        delete validators[pubKeyHash];
    }

    /**
     * @dev Retrieves a validator session for a given public key
     * @param _pubKey Public key to lookup
     * @return session The validator session
     */
    function _getValidatorSession(
        bytes calldata _pubKey
    ) internal view returns (Session memory session) {
        session = validators[keccak256(_pubKey)];

        if (!valid(session)) revert InvalidValidatorSession();
    }

    /**
     * @dev Checks if a validator is installed with given data
     * @param _validator Address of the validator to check
     * @param data Encoded data containing public key hash
     * @return bool True if validator is installed and valid
     */
    function _isValidatorInstalled(
        address _validator,
        bytes calldata data
    ) internal view returns (bool) {
        bytes32 pubKeyHash = abi.decode(data, (bytes32));
        Session memory session = validators[pubKeyHash];
        return session.validator == _validator && valid(session);
    }

    /**
     * @dev Checks if a session is currently valid based on its time bounds
     * @param session The session to validate
     * @return bool True if the session is currently valid
     */
    function valid(Session memory session) internal view returns (bool) {
        return
            session.validUntil > block.timestamp &&
            session.validFrom <= block.timestamp;
    }
}
