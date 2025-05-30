// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "../utils/Types.sol";

/**
 * @title Configuration interface for wallet management
 * @notice Interface for managing wallet configurations, signers, and whitelists
 */
interface IConfig {
    /**
     * @notice Emitted when bundlers are added to whitelist
     * @param bundlers Array of bundler addresses added
     */
    event WhitelistBundlerAdded(address[] bundlers);

    /**
     * @notice Emitted when bundlers are removed from whitelist
     * @param bundlers Array of bundler addresses removed
     */
    event WhitelistBundlerRemoved(address[] bundlers);

    /**
     * @notice Emitted when a module is added to whitelist
     * @param module Address of the module added
     * @param moduleType Type identifier for the module
     */
    event WhitelistModuleAdded(address module, uint256 moduleType);

    /**
     * @notice Emitted when a module is removed from whitelist
     * @param module Address of the module removed
     */
    event WhitelistModuleRemoved(address module);

    /**
     * @notice Emitted when recovery signer is added
     * @param signer New recovery signer address
     */
    event RecoverySignerAdded(address signer);

    /**
     * @notice Emitted when recovery signer is removed
     * @param signer Recovery signer address removed
     */
    event RecoverySignerRemoved(address signer);

    /**
     * @notice Emitted when factory signer is updated
     * @param signer New factory signer address
     */
    event FactorySignerUpdated(address signer);

    /**
     * @notice Emitted when pay signer is updated
     * @param signer New pay signer address
     */
    event PaySignerUpdated(address signer);

    /**
     * @notice Emitted when sender signer is set
     * @param sender Wallet address
     * @param signer Signer address
     * @param timestamp Time when signer was set
     */
    event SetSenderSigner(address sender, address signer, uint256 timestamp);

    /**
     * @notice Emitted when safe singleton status is updated
     * @param singleton Address of the singleton
     * @param status New status of the singleton
     * @param timestamp Time when status was updated
     */
    event SetSafeSingleton(address singleton, bool status, uint256 timestamp);

    /**
     * @notice Emitted when verifier is added
     * @param verifier New verifier
     */
    event VerifierTypeAdded(VerifierType verifier);

    /**
     * @notice Emitted when verifier is removed
     * @param verifier verifier is removed
     */
    event VerifierTypeRemoved(VerifierType verifier);

    /**
     * @notice Checks if an address is a whitelisted Safe singleton
     * @dev Used to validate wallet implementations
     * @param singleton The singleton address to check
     * @return bool True if address is a whitelisted singleton
     */
    function isSafeSingleton(address singleton) external view returns (bool);

    /**
     * @notice Gets the EOA signer for a wallet address
     * @param sender Wallet address to query
     * @return address EOA signer address
     */
    function walletSigner(address sender) external view returns (address);

    /**
     * @notice Gets the recovery signer address
     * @return address Recovery signer address
     */
    function isRecoverySigner(address signer) external view returns (bool);

    /**
     * @notice Check if sender is a factory signer.
     * @return ture if sender is factory signer
     */
    function isFactorySigner(address sender) external view returns (bool);

    /**
     * @notice Check if sender is a pay signer.
     * @return ture if sender is pay signer
     */
    function isPaySigner(address sender) external view returns (bool);

    /**
     * @notice Adds multiple bundlers to whitelist
     * @param bundlers Array of bundler addresses to whitelist
     */
    function addWhitelistedBundlers(address[] memory bundlers) external;

    /**
     * @notice Removes multiple bundlers from whitelist
     * @param bundlers Array of bundler addresses to remove
     */
    function removeWhitelistedBundlers(address[] memory bundlers) external;

    /**
     * @notice Checks if an address is a whitelisted bundler
     * @param bundler Address to check
     * @return bool True if address is a whitelisted bundler
     */
    function isWhitelistedBundler(address bundler) external view returns (bool);

    /**
     * @notice Checks if Verifier is whitelisted;
     * @param verifier verifier to check
     * @return bool True if verifier is whitelisted;
     */
    function isWhitelistedVerifier(
        VerifierType verifier
    ) external view returns (bool);

    /**
     * @notice Adds multiple modules to whitelist
     * @param modules Array of module addresses to whitelist
     * @param moduleTypes Array of corresponding module types
     */
    function addWhitelistedModules(
        address[] memory modules,
        uint256[] memory moduleTypes
    ) external;

    /**
     * @notice Removes multiple modules from whitelist
     * @param modules Array of module addresses to remove
     */
    function removeWhitelistedModules(address[] memory modules) external;

    /**
     * @notice Gets the type of a whitelisted module
     * @param module Module address to query
     * @return moduleType Type identifier of the module
     */
    function whitelistedModuleType(
        address module
    ) external view returns (uint256 moduleType);

    /**
     * @notice Adds the recovery signer address
     * @param signer New recovery signer address
     */
    function addRecoverySigner(address signer) external;

    /**
     * @notice Removes the recovery signer address
     * @param signer Recovery signer address to remove
     */
    function removeRecoverySigner(address signer) external;

    /**
     * @notice Adds verifier to whitelist
     * @param verifier VerifierType to be added
     */
    function addWhitelistedVerifier(VerifierType verifier) external;

    /**
     * @notice Removes verifier from whitelist
     * @param verifier VerifierType to be added
     */
    function removeWhitelistedVerifier(VerifierType verifier) external;

    /**
     * @notice initlialize the signer for a wallet address
     * @param signer New signer address
     */
    function initializeWalletSigner(address signer) external;
}
