// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./interfaces/IPayableAccount.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/IERC7579Account.sol";
import "./interfaces/IERC7579Module.sol";
import "./interfaces/IRecoveryModule.sol";

import "./managers/ValidationManager.sol";
import "./managers/ExecutionManager.sol";
import "./managers/FallbackManager.sol";
import "./managers/HookManager.sol";
import "./utils/Constants.sol";

import "./lib/DecodeLib.sol";
import "./lib/ModeLib.sol";

/**
 * @title PayableAccount
 * @notice A smart contract wallet implementation that supports account abstraction (ERC-4337),
 * modular functionality, and recovery mechanisms.
 * @dev Inherits from multiple manager contracts to handle different aspects of functionality
 */
contract PayableAccount is
    IPayableAccount,
    Initializable,
    ValidationManager,
    ExecutionManager,
    FallbackManager,
    HookManager,
    UUPSUpgradeable
{
    using DecodeLib for bytes;
    using StructuredLinkedList for StructuredLinkedList.List;

    /**
     * @notice The EntryPoint contract address
     * @dev Immutable reference to the ERC-4337 EntryPoint
     */
    IEntryPoint public immutable ENTRYPOINT;

    /**
     * @notice The configuration contract address
     * @dev Immutable reference to configuration settings
     */
    IConfig public immutable CONFIG;

    /**
     * @notice Mapping to track recovery modules
     * @dev Maps module address to boolean indicating if it's a recovery module
     */
    mapping(address => bool) public isRecoveryModule;

    /**
     * @dev Modifier to make a function callable only by the ENTRYPOINT.
     */
    modifier onlyEntryPoint() {
        if (msg.sender != address(ENTRYPOINT)) revert NotFromEntryPoint();
        _;
    }

    /**
     * @dev Modifier to make a function callable only by the ENTRYPOINT or self.
     */
    modifier onlyEntryPointOrSelf() {
        if (msg.sender != address(ENTRYPOINT) && msg.sender != address(this))
            revert NotFromEntryPointOrSelf();
        _;
    }

    /**
     * @dev Modifier to make a function callable only by a whitelisted bundler.
     */
    modifier onlyWhiteListedBundler() {
        if (!CONFIG.isWhitelistedBundler(tx.origin)) revert InvalidBundler();
        _;
    }

    /**
     * @dev Modifier to make a function callable only by recovery modules.
     */
    modifier onlyRecoveryModule() {
        if (!isRecoveryModule[msg.sender]) revert InvalidRecoveryModule();
        _;
    }

    /**
     * @dev Modifier that handles paying the prefund to the caller (EntryPoint)
     * @param missingAccountFunds The amount of funds that need to be paid to the EntryPoint
     * @notice Uses inline assembly for gas optimization when making the payment
     */
    modifier payPrefund(uint256 missingAccountFunds) {
        assembly ("memory-safe") {
            if missingAccountFunds {
                // Ignore failure (it's EntryPoint's job to verify, not the account's).
                pop(
                    call(
                        gas(),
                        caller(),
                        missingAccountFunds,
                        codesize(),
                        0x00,
                        codesize(),
                        0x00
                    )
                )
            }
        }
        _;
    }

    /**
     * @notice Constructor sets up immutable contract references
     * @param entrypoint The address of the ERC-4337 EntryPoint contract
     * @param _config The address of the configuration contract
     */
    constructor(address entrypoint, address _config) {
        ENTRYPOINT = IEntryPoint(entrypoint);
        CONFIG = IConfig(_config);

        _disableInitializers();
    }

    /**
     * @notice Handles receiving ETH
     * @dev Emits SafeReceived event when ETH is received
     */
    receive() external payable {
        emit SafeReceived(msg.sender, msg.value);
    }

    /**
     * @notice Fallback function that delegates calls to the fallback handler
     * @dev Reverts if no fallback handler is set
     */
    fallback() external {
        // Forward to fallbackHandler
        if (fallbackHandler == address(0)) revert InvalidFallbackHandler();
        (bool success, bytes memory returnData) = fallbackHandler.staticcall(
            msg.data
        );
        if (!success)
            assembly {
                revert(add(0x20, returnData), mload(returnData))
            }

        assembly {
            return(add(0x20, returnData), mload(returnData))
        }
    }

    /**
     * @notice Initializes the account with validators and executions
     * @param data Encoded initialization parameters including subjects, executions, validator, and EOA signer
     */
    function initialize(bytes calldata data) external initializer {
        (
            bytes[] calldata _subjects,
            Execution[] calldata _executions,
            address _validator,
            address _eoaSigner
        ) = data.decodeInitParams();

        uint256 subjectCount = _subjects.length;
        if (subjectCount == 0) revert PassKeyError();

        if (
            CONFIG.whitelistedModuleType(_validator) !=
            MODULE_TYPE_STATELESS_VALIDATOR
        ) revert InvalidModule();

        for (uint256 i; i < subjectCount; ) {
            _installStatelessValidator(_validator, _subjects[i]);

            emit ModuleInstalledWithData(
                MODULE_TYPE_STATELESS_VALIDATOR,
                _validator,
                _subjects[i]
            );
            emit ModuleInstalled(MODULE_TYPE_STATELESS_VALIDATOR, _validator);

            unchecked {
                ++i;
            }
        }
        /// recovery / fallback and other required executions should be installed here
        _handleBatchExecution(
            address(0),
            EXECTYPE_DEFAULT,
            MODE_DEFAULT,
            _executions,
            MODE_PAYLOAD_DEFAULT
        );

        CONFIG.initializeWalletSigner(_eoaSigner);
    }

    /**
     * @notice Validates a UserOperation as per ERC-4337
     * @param userOp The UserOperation to validate
     * @param userOpHash The hash of the UserOperation
     * @param missingAccountFunds The required funds to be paid
     * @return validationData The packed validation data
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        onlyEntryPoint
        onlyWhiteListedBundler
        payPrefund(missingAccountFunds)
        returns (uint256)
    {
        (
            bytes calldata pubKey,
            bytes calldata signatures,
            uint256 validationData
        ) = DecodeLib.decodeSignature(userOp.signature);
        Session memory session = _getValidatorSession(pubKey);
        // Validate the signature
        if (
            !IStatelessValidator(session.validator).validateSignatureWithData(
                keccak256(abi.encode(userOpHash, validationData)), // including expire time in the signature
                signatures,
                pubKey
            )
        ) return SIG_VALIDATION_FAILED;

        return validationData;
    }

    /**
     * @notice Executes a transaction through the EntryPoint or self
     * @param execMode The execution mode parameters
     * @param executionCalldata The calldata to execute
     */
    function execute(
        bytes32 execMode,
        bytes calldata executionCalldata
    ) external override onlyEntryPointOrSelf {
        _execute(executionHook, ModeCode.wrap(execMode), executionCalldata);
    }

    /**
     * @notice Executes a transaction from an installed executor module
     * @param execMode The execution mode parameters
     * @param executionCalldata The calldata to execute
     * @return returnData The data returned from the execution
     */
    function executeFromExecutor(
        bytes32 execMode,
        bytes calldata executionCalldata
    ) external override returns (bytes[] memory returnData) {
        if (!_isExecutorInstalled(msg.sender)) revert InvalidExecutor();
        return
            _execute(executionHook, ModeCode.wrap(execMode), executionCalldata);
    }

    /**
     * @notice Recovers the account using a recovery module
     * @param validator The new validator address
     * @param data The recovery data
     * @dev Can only be called by a recovery module
     */
    function recover(
        address validator,
        bytes calldata data
    ) external override onlyRecoveryModule {
        // Get latest updated pubkey
        (, uint256 _node) = pubKeyHashes.getNextNode(0);
        (, uint128 newValidFrom, ) = abi.decode(
            data,
            (bytes32, uint128, uint128)
        );
        uint128 lastValidFrom = validators[bytes32(_node)].validFrom;

        // lastValidFrom > block.timestamp means waiting period, ignored
        if (lastValidFrom <= block.timestamp && lastValidFrom > newValidFrom)
            revert RecoveryExpired(lastValidFrom, newValidFrom);

        // Clean all pubkeys
        while (pubKeyHashes.listExists()) {
            uint256 node = pubKeyHashes.popBack();
            bytes32 pubKeyHash = bytes32(node);
            delete validators[pubKeyHash];
        }

        if (
            CONFIG.whitelistedModuleType(validator) !=
            MODULE_TYPE_STATELESS_VALIDATOR
        ) revert InvalidModule();

        if (
            !IStatelessValidator(validator).isModuleType(
                MODULE_TYPE_STATELESS_VALIDATOR
            )
        ) revert InvalidValidator();
        _installStatelessValidator(validator, data);

        emit AccountRecovered(validator, data);
    }

    /**
     * @notice Claims the recovery fee for a successful recovery
     * @param receiver The address to receive the fee
     * @param value The amount of fee to claim
     * @dev Can only be called by a recovery module
     */
    function claimRecoveryFee(
        address receiver,
        uint256 value
    ) external onlyRecoveryModule {
        if (receiver == address(0)) revert InvalidAddress();

        (bool success, ) = receiver.call{value: value}("");
        if (!success) revert RecoveryFeePaymentFailed(receiver, value);
        emit RecoveryFeeClaimed(receiver, value);
    }

    /**
     * @notice Installs a new recovery module
     * @param recoveryModule The address of the recovery module to install
     * @param data Additional installation data
     */
    function installRecoveryModule(
        address recoveryModule,
        bytes calldata data
    ) external override onlyEntryPointOrSelf {
        if (
            CONFIG.whitelistedModuleType(recoveryModule) !=
            MODULE_TYPE_EXECUTOR ||
            !IRecoveryModule(recoveryModule).isModuleType(MODULE_TYPE_EXECUTOR)
        ) revert InvalidModule();
        isRecoveryModule[recoveryModule] = true;
        IRecoveryModule(recoveryModule).onInstall(data);
        emit RecoveryModuleInstalled(recoveryModule);
    }

    /**
     * @notice Uninstalls a recovery module
     * @param recoveryModule The address of the recovery module to uninstall
     * @param data Additional uninstallation data
     */
    function uninstallRecoveryModule(
        address recoveryModule,
        bytes calldata data
    ) external override onlyEntryPointOrSelf {
        delete isRecoveryModule[recoveryModule];
        IRecoveryModule(recoveryModule).onUninstall(data);
        emit RecoveryModuleUninstalled(recoveryModule);
    }

    /**
     * @notice Installs a new module of the specified type
     * @param typeId The type ID of the module
     * @param module The address of the module to install
     * @param data Additional installation data
     */
    function installModule(
        uint256 typeId,
        address module,
        bytes calldata data
    ) external override onlyEntryPointOrSelf {
        // Check module
        (bool success, bytes memory result) = module.call(
            abi.encodeWithSelector(IModule.isModuleType.selector, typeId)
        );

        if (!success || result.length == 0) revert InvalidModule();

        bool isMatched = abi.decode(result, (bool));
        if (!isMatched) revert InvalidModule();

        if (CONFIG.whitelistedModuleType(module) != typeId)
            revert InvalidModule();

        // Install module
        if (typeId == MODULE_TYPE_STATELESS_VALIDATOR) {
            _installStatelessValidator(module, data);
        } else if (typeId == MODULE_TYPE_EXECUTOR)
            _installExecutor(module, data);
        else if (typeId == MODULE_TYPE_FALLBACK) _installFallback(module, data);
        else if (typeId == MODULE_TYPE_HOOK) _installHook(module, data);
        else revert UnsupportedModule(typeId);

        emit ModuleInstalled(typeId, module);
        emit ModuleInstalledWithData(typeId, module, data);
    }

    /**
     * @notice Uninstalls a module of the specified type
     * @param typeId The type ID of the module
     * @param module The address of the module to uninstall
     * @param data Additional uninstallation data
     */
    function uninstallModule(
        uint256 typeId,
        address module,
        bytes calldata data
    ) external override onlyEntryPointOrSelf {
        if (typeId == MODULE_TYPE_STATELESS_VALIDATOR)
            _uninstallStatelessValidator(module, data);
        else if (typeId == MODULE_TYPE_EXECUTOR)
            _uninstallExecutor(module, data);
        else if (typeId == MODULE_TYPE_FALLBACK)
            _uninstallFallback(module, data);
        else if (typeId == MODULE_TYPE_HOOK) _uninstallHook(module, data);
        else revert UnsupportedModule(typeId);

        emit ModuleUninstalled(typeId, module);
        emit ModuleUninstalledWithData(typeId, module, data);
    }

    /**
     * @notice Checks if a module is installed
     * @param moduleTypeId The type ID of the module
     * @param module The address of the module to check
     * @param additionalContext Additional context for the check
     * @return bool True if the module is installed
     */
    function isModuleInstalled(
        uint256 moduleTypeId,
        address module,
        bytes calldata additionalContext
    ) external view returns (bool) {
        if (moduleTypeId == MODULE_TYPE_STATELESS_VALIDATOR)
            return _isValidatorInstalled(module, additionalContext);
        else if (moduleTypeId == MODULE_TYPE_EXECUTOR)
            return _isExecutorInstalled(module);
        else if (moduleTypeId == MODULE_TYPE_FALLBACK)
            return _isFallbackInstalled(module);
        else if (moduleTypeId == MODULE_TYPE_HOOK)
            return _isHookInstalled(module);
        else revert UnsupportedModule(moduleTypeId);
    }

    /**
     * @notice Validates a signature according to EIP-1271
     * @param _hash The hash of the data to be signed
     * @param _signature The signature to validate
     * @return bytes4 The magic value indicating if the signature is valid
     */
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4) {
        (bytes calldata pubKey, bytes calldata signature, ) = DecodeLib
            .decodeSignature(_signature);

        bytes32 boundHash = keccak256(
            abi.encode(abi.encode(bytes32(block.chainid), address(this)), _hash)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", boundHash));

        // revert if session is invalid
        Session memory session = _getValidatorSession(pubKey);

        return
            IStatelessValidator(session.validator).validateSignatureWithData(
                digest,
                signature,
                pubKey
            )
                ? MAGIC_VALUE
                : INVALID_VALUE;
    }

    /**
     * @notice Checks if the contract supports a specific module type
     * @param moduleTypeId The type ID of the module
     * @return bool True if the module type is supported
     */
    function supportsModule(
        uint256 moduleTypeId
    ) external pure virtual returns (bool) {
        if (moduleTypeId == MODULE_TYPE_EXECUTOR) return true;
        if (moduleTypeId == MODULE_TYPE_FALLBACK) return true;
        if (moduleTypeId == MODULE_TYPE_HOOK) return true;
        if (moduleTypeId == MODULE_TYPE_STATELESS_VALIDATOR) return true;
        return false;
    }

    /**
     * @notice Returns the account implementation identifier
     * @return accountImplementationId The identifier string
     */
    function accountId()
        external
        pure
        virtual
        returns (string memory accountImplementationId)
    {
        accountImplementationId = PAYABLE_ACCOUNT;
    }

    /**
     * @dev Internal function to authorize contract upgrades
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyEntryPointOrSelf {
        if (!CONFIG.isSafeSingleton(newImplementation))
            revert InvalidSingleton(newImplementation);
    }
}
