// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IConfig, VerifierType} from "./interfaces/IConfig.sol";
import "./utils/Errors.sol";

/**
 * @title Config
 * @dev Contract for managing configuration settings including bundlers, modules, and signers
 * @notice This contract handles whitelisting of bundlers, modules, and manages wallet signers
 */
contract Config is IConfig, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => bool) public override isRecoverySigner;
    mapping(address => bool) public override isWhitelistedBundler;
    mapping(address => uint256) public override whitelistedModuleType;
    mapping(address => bool) public override isSafeSingleton;
    mapping(address => address) public override walletSigner;
    mapping(VerifierType => bool) public override isWhitelistedVerifier;
    mapping(address => bool) public override isFactorySigner;
    mapping(address => bool) public override isPaySigner;

    /**
     * @dev Constructor that disables initializers
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract
     * @param "" Unused parameter
     * @param _initialOwner Address of the initial contract owner
     */
    function initialize(address, address _initialOwner) external initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Adds multiple bundlers to the whitelist. Emits WhitelistBundlerAdded event.
     * @param bundlers Array of bundler addresses to whitelist
     * @notice Only callable by contract owner
     */
    function addWhitelistedBundlers(
        address[] memory bundlers
    ) external override onlyOwner {
        uint256 length = bundlers.length;
        for (uint256 i = 0; i < length; ) {
            address bundler = bundlers[i];
            isWhitelistedBundler[bundler] = true;

            unchecked {
                ++i;
            }
        }

        emit WhitelistBundlerAdded(bundlers);
    }

    /**
     * @dev Removes multiple bundlers from the whitelist. Emits WhitelistBundlerRemoved event.
     * @param bundlers Array of bundler addresses to remove
     * @notice Only callable by contract owner
     */
    function removeWhitelistedBundlers(
        address[] memory bundlers
    ) external onlyOwner {
        uint256 length = bundlers.length;
        for (uint256 i = 0; i < length; ) {
            address bundler = bundlers[i];
            delete isWhitelistedBundler[bundler];

            unchecked {
                ++i;
            }
        }

        emit WhitelistBundlerRemoved(bundlers);
    }

    /**
     * @dev Adds multiple modules to the whitelist with their corresponding types.
     * Emits WhitelistModuleAdded event for each module.
     * @param modules Array of module addresses to whitelist
     * @param moduleTypes Array of corresponding module types
     * @notice Only callable by contract owner
     */
    function addWhitelistedModules(
        address[] memory modules,
        uint256[] memory moduleTypes
    ) external override onlyOwner {
        uint256 length = modules.length;
        if (length != moduleTypes.length) revert LengthNotMatch();

        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                address module = modules[i];
                uint256 moduleType = moduleTypes[i];

                whitelistedModuleType[module] = moduleType;
                emit WhitelistModuleAdded(module, moduleType);
            }
        }
    }

    /**
     * @dev Removes multiple modules from the whitelist. Emits WhitelistModuleRemoved event.
     * @param modules Array of module addresses to remove
     * @notice Only callable by contract owner
     */
    function removeWhitelistedModules(
        address[] memory modules
    ) external override onlyOwner {
        unchecked {
            uint256 length = modules.length;
            for (uint256 i = 0; i < length; ++i) {
                address module = modules[i];
                delete whitelistedModuleType[module];
                emit WhitelistModuleRemoved(module);
            }
        }
    }

    /**
     * @dev initialize the signer address for a specific wallet. Emits SetSenderSigner event.
     * @param signer Address of the signer
     */
    function initializeWalletSigner(address signer) external {
        if (signer == address(0) || walletSigner[msg.sender] != address(0))
            revert InvalidAddress();

        if (!isWhitelistedBundler[tx.origin]) revert InvalidBundler();
        walletSigner[msg.sender] = signer;
        emit SetSenderSigner(msg.sender, signer, block.timestamp);
    }

    /**
     * @dev batch reset the signer address for a specific wallet. Emits SetSenderSigner event.
     * @param wallets Address set of the aa
     * @param signers Address set of the signer
     * @notice Only callable by owner
     */
    function batchResetWalletSigner(
        address[] calldata wallets,
        address[] calldata signers
    ) external onlyOwner {
        uint256 signersLength = signers.length;
        uint256 walletsLength = wallets.length;
        if (signersLength != walletsLength) revert LengthNotMatch();

        for (uint256 i; i < signersLength; ) {
            address signer = signers[i];
            address wallet = wallets[i];
            if (signer == address(0)) revert InvalidAddress();

            walletSigner[wallet] = signer;
            emit SetSenderSigner(wallet, signer, block.timestamp);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Adds the recovery signer address. Emits RecoverySignerAdded event.
     * @param signer Address of the recovery signer
     * @notice Only callable by contract owner
     */
    function addRecoverySigner(address signer) external onlyOwner {
        if (signer == address(0)) revert InvalidAddress();

        isRecoverySigner[signer] = true;
        emit RecoverySignerAdded(signer);
    }

    /**
     * @dev Removes the recovery signer address. Emits RecoverySignerRemoved event.
     * @param signer Address of the recovery signer
     * @notice Only callable by contract owner
     */
    function removeRecoverySigner(address signer) external onlyOwner {
        delete isRecoverySigner[signer];
        emit RecoverySignerRemoved(signer);
    }

    /**
     * @dev Sets the recovery signer address. Emits RecoverySignerUpdated event.
     * @param signer Address of the recovery signer
     * @notice Only callable by contract owner
     */
    function setFactorySigner(address signer) external onlyOwner {
        if (signer == address(0)) revert InvalidAddress();

        isFactorySigner[signer] = true;
        emit FactorySignerUpdated(signer);
    }

    /**
     * @dev Adds multiple factory signers. Emits FactorySignerUpdated event for each signer.
     * @param signers Array of factory signer addresses
     * @notice Only callable by contract owner
     */
    function addFactorySigners(address[] memory signers) external onlyOwner {
        uint256 length = signers.length;
        for (uint256 i = 0; i < length; ) {
            address signer = signers[i];
            if (signer == address(0)) revert InvalidAddress();
            
            isFactorySigner[signer] = true;
            emit FactorySignerUpdated(signer);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Sets a pay signer address. Emits PaySignerUpdated event.
     * @param signer Address of the pay signer
     * @notice Only callable by contract owner
     */
    function setPaySigner(address signer) external onlyOwner {
        if (signer == address(0)) revert InvalidAddress();

        isPaySigner[signer] = true;
        emit PaySignerUpdated(signer);
    }

    /**
     * @dev Adds multiple pay signers. Emits PaySignerUpdated event for each signer.
     * @param signers Array of pay signer addresses
     * @notice Only callable by contract owner
     */
    function addPaySigners(address[] memory signers) external onlyOwner {
        uint256 length = signers.length;
        for (uint256 i = 0; i < length; ) {
            address signer = signers[i];
            if (signer == address(0)) revert InvalidAddress();
            
            isPaySigner[signer] = true;
            emit PaySignerUpdated(signer);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Adds a Safe singleton to the whitelist. Emits SetSafeSingleton event.
     * @param singleton Address of the Safe singleton
     * @notice Only callable by contract owner
     */
    function addSafeSingleton(address singleton) external onlyOwner {
        if (singleton == address(0)) revert InvalidAddress();
        isSafeSingleton[singleton] = true;

        emit SetSafeSingleton(singleton, true, block.timestamp);
    }

    /**
     * @dev Removes a Safe singleton from the whitelist. Emits SetSafeSingleton event.
     * @param singleton Address of the Safe singleton to remove
     * @notice Only callable by contract owner
     */
    function removeSafeSingleton(address singleton) external onlyOwner {
        delete isSafeSingleton[singleton];

        emit SetSafeSingleton(singleton, false, block.timestamp);
    }

    /**
     * @notice Adds verifier to whitelist
     * @param verifier VerifierType to be added
     */
    function addWhitelistedVerifier(VerifierType verifier) external onlyOwner {
        isWhitelistedVerifier[verifier] = true;
        emit VerifierTypeAdded(verifier);
    }

    /**
     * @notice Removes verifier from whitelist
     * @param verifier VerifierType to be added
     */
    function removeWhitelistedVerifier(
        VerifierType verifier
    ) external onlyOwner {
        delete isWhitelistedVerifier[verifier];
        emit VerifierTypeRemoved(verifier);
    }

    /**
     * @dev Internal function to authorize an upgrade
     * @param newImplementation Address of the new implementation
     * @notice Only callable by contract owner
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
