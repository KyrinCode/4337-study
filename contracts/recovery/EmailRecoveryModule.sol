// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEmailRecoveryModule} from "../interfaces/IEmailRecoveryModule.sol";
import {MODULE_TYPE_EXECUTOR} from "../interfaces/IERC7579Module.sol";
import {IConfig} from "../interfaces/IConfig.sol";
import {IDkimKeyOracle} from "../interfaces/IDkimKeyOracle.sol";
import {IPayableAccount} from "../interfaces/IPayableAccount.sol";
import {IZkEmailVerifier} from "../interfaces/IZkEmailVerifier.sol";

/**
 * @title EmailRecoveryModule
 * @notice A contract for email-based account recovery
 * @dev Implements email verification and ZK proofs for secure account recovery
 */
contract EmailRecoveryModule is IEmailRecoveryModule, Ownable {
    /**
     * @notice ZK Email Verifier contract address
     * @dev Used to verify email ZK proofs
     */
    address public immutable ZK_EMAIL_VERIFIER;

    /**
     * @notice Base cost for recovery fee
     */
    uint256 public constant RECOVERY_FEE_BASE_COST = 39799;

    /**
     * @notice Configuration contract address
     * @dev Used to access system-wide configuration settings
     */
    address public config;

    /**
     * @notice Oracle contract address for DKIM verification
     * @dev Used to verify email dkim key hash
     */
    address public getOracle;

    /**
     * @notice Mapping of account addresses to their nonces
     * @dev Used to prevent replay attacks
     */
    mapping(address => uint256) public accountNonces;

    /**
     * @notice Structure containing email hash data
     * @param emailHash Hash of the email address
     * @param lastUpdatedAt Timestamp of the last update
     */
    struct EmailHash {
        bytes32 emailHash;
        uint256 lastUpdatedAt;
    }

    /**
     * @notice Mapping of account addresses to their email hash data
     * @dev Private mapping to store email hashes and update timestamps
     */
    mapping(address => EmailHash) private emailHashes;

    modifier onlyRecoverySigner() {
        if (!IConfig(config).isRecoverySigner(msg.sender))
            revert InvalidSigner();
        _;
    }

    /**
     * @dev Constructs the EmailRecoveryModule contract.
     * @param _config The address of the configuration contract.
     * @param _oracle The address of the DKIM key oracle contract.
     * @param _owner The address of the contract owner. It only has the ability to update the oracle address.
     */
    constructor(
        address _config,
        address _oracle,
        address _zkEmailVerifier,
        address _owner
    ) Ownable(_owner) {
        config = _config;
        getOracle = _oracle;
        ZK_EMAIL_VERIFIER = _zkEmailVerifier;
    }

    /**
     * @notice Updates the oracle address
     * @dev Can only be called by the contract owner. Reverts if _newOracle is zero address. Emits OracleUpdated event.
     * @param _newOracle Address of the new oracle contract
     */
    function setOracle(address _newOracle) external onlyOwner {
        if (_newOracle == address(0)) revert InvalidAddress();

        getOracle = _newOracle;
        emit OracleUpdated(_newOracle);
    }

    /**
     * @notice Retrieves the email hash and last update timestamp for an account
     * @param _account Address of the account to query
     * @return _emailHash Hash of the email associated with the account
     * @return _lastUpdatedAt Timestamp of the last email hash update
     */
    function getEmailHash(
        address _account
    ) public view returns (bytes32 _emailHash, uint256 _lastUpdatedAt) {
        _emailHash = emailHashes[_account].emailHash;
        _lastUpdatedAt = emailHashes[_account].lastUpdatedAt;
    }

    /**
     * @notice Updates the email hash for the caller's account
     * @param _emailHash New email hash to set
     * @dev Wrapper around _updateEmailHash for external calls
     */
    function updateEmailHash(bytes32 _emailHash) external {
        _updateEmailHash(msg.sender, _emailHash);
    }

    /**
     * @notice Handles module installation
     * @param data Encoded email hash data
     * @dev Called when the module is installed on an account
     */
    function onInstall(bytes calldata data) external {
        _updateEmailHash(msg.sender, abi.decode(data, (bytes32)));
    }

    /**
     * @notice Handles module uninstallation
     * @dev Called when the module is uninstalled from an account
     */
    function onUninstall(bytes calldata) external {
        delete emailHashes[msg.sender];
        emit EmailHashUpdated(msg.sender, bytes32(0), 0);
    }

    /**
     * @notice Recovers an account using email proof
     * @dev Processes recovery request and updates account access. Reverts on invalid nonce, signature, or proof.
     * @param account Address of the account to recover
     * @param data Encoded recovery data containing validator, public key hash, signature, email proof, and refund address
     */
    function recover(
        address account,
        bytes calldata data
    ) external onlyRecoverySigner {
        uint256 preGas = gasleft();
        (
            address _validator,
            bytes32 _newPubKeyHash,
            bytes memory _proof,
            address _refundTo
        ) = abi.decode(data, (address, bytes32, bytes, address));

        (
            bool success,
            bytes32 _emailHash,
            bytes32 _dkimKeyHash,
            uint256 _timestamp,
            string memory _domain
        ) = IZkEmailVerifier(ZK_EMAIL_VERIFIER).verify(
                account,
                _validator,
                _newPubKeyHash,
                _proof
            );

        if (!success) revert InvalidProof();

        if (accountNonces[account] >= _timestamp) revert InvalidAccountNonce();

        // Verify Recovery Email Hash
        if (_emailHash != emailHashes[account].emailHash)
            revert InvalidEmailHash();

        // Verify Email DKIM Key Hash
        bytes32 domainHash = keccak256(abi.encode(_domain));
        if (IDkimKeyOracle(getOracle).getDomainHash(_dkimKeyHash) != domainHash)
            revert InvalidDkimKeyHash();

        IPayableAccount(account).recover(
            _validator,
            abi.encode(_newPubKeyHash, _timestamp, type(uint128).max)
        );

        accountNonces[account] = _timestamp;

        if (_refundTo != address(0))
            IPayableAccount(account).claimRecoveryFee(
                _refundTo,
                (preGas + RECOVERY_FEE_BASE_COST - gasleft()) * tx.gasprice
            );
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR;
    }
    /**
     * @notice Internal function to update email hash
     * @dev Updates the email hash and timestamp for an account. Emits EmailHashUpdated event.
     * @param _account Address of the account
     * @param _emailHash New email hash to set
     */
    function _updateEmailHash(address _account, bytes32 _emailHash) internal {
        if (_emailHash == bytes32(0)) revert InvalidEmailHash();
        emailHashes[_account] = EmailHash(_emailHash, block.timestamp);
        emit EmailHashUpdated(_account, _emailHash, block.timestamp);
    }
}
