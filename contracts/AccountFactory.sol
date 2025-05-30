// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IAccountFactory} from "./interfaces/IAccountFactory.sol";
import {AccountProxy} from "./AccountProxy.sol";
import {IConfig} from "./interfaces/IConfig.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./utils/Errors.sol";

/**
 * @title AccountFactory
 * @dev Factory contract for creating and managing account proxies
 * @notice This contract handles the creation of new account proxies and maintains a registry of valid accounts
 */
contract AccountFactory is
    IAccountFactory,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @notice Reference to the configuration contract
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IConfig public immutable CONFIG;

    /// @notice Hash of the creation code for AccountProxy
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    bytes32 private immutable CREATION_CODE_HASH;

    /// @notice Mapping to track valid accounts created by this factory
    /// @dev Maps account address to boolean indicating validity
    mapping(address => bool) public override isValidAccount;

    /**
     * @dev Constructor that sets up immutable state variables
     * @param config Address of the configuration contract
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address config) {
        CONFIG = IConfig(config);
        CREATION_CODE_HASH = keccak256(
            abi.encodePacked(type(AccountProxy).creationCode)
        );
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the initial owner
     * @param initialOwner Address of the initial owner
     */
    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Creates a new account proxy
     * @dev Only whitelisted signer can call this function
     * @param _implementation Address of the implementation contract
     * @param _initializer Initialization data for the new account
     * @param _salt Salt value for deterministic address generation
     * @return Address of the newly created account
     */
    function createAccount(
        address _implementation,
        bytes calldata _initializer,
        uint256 _salt
    ) external returns (address) {
        if (!CONFIG.isFactorySigner(msg.sender)) revert NotAllowed();
        return _createAccount(_implementation, _initializer, _salt);
    }

    /**
     * @notice Creates a new account using a signature for authorization
     * @param _implementation The address of the implementation contract to use
     * @param _initializer The initialization data for the new account
     * @param _salt A unique value to ensure unique account addresses
     * @param _signature factory signer' signature authorizing account creation
     * @return address The address of the newly created account
     */
    function createAccountWithSignature(
        address _implementation,
        bytes calldata _initializer,
        uint256 _salt,
        bytes calldata _signature
    ) external returns (address) {
        uint256 expireTime = uint256(bytes32(_signature[:32]));
        if (expireTime < block.timestamp) {
            revert Expired(expireTime, block.timestamp);
        }

        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
            keccak256(
                abi.encode(
                    block.chainid,
                    address(this),
                    _initializer,
                    _salt,
                    expireTime
                )
            )
        );

        address signer = ECDSA.recover(msgHash, _signature[32:]);
        if (!CONFIG.isFactorySigner(signer)) revert InvalidSignature();

        return _createAccount(_implementation, _initializer, _salt);
    }

    /**
     * @dev Internal function to create and initialize a new account proxy
     * @param _implementation Address of the implementation contract
     * @param _initializer Initialization data for the new account
     * @param _salt Salt value for deterministic address generation
     * @return Address of the newly created account
     */
    function _createAccount(
        address _implementation,
        bytes calldata _initializer,
        uint256 _salt
    ) private returns (address) {
        if (!CONFIG.isSafeSingleton(_implementation))
            revert InvalidSingleton(_implementation);

        address account = address(new AccountProxy{salt: bytes32(_salt)}());
        AccountProxy(payable(account)).initialize(
            _implementation,
            _initializer
        );

        isValidAccount[account] = true;

        emit AccountCreated(account, _implementation, _initializer, _salt);

        return account;
    }

    /**
     * @notice Computes the address of an account before it is created
     * @dev Uses CREATE2 address computation
     * @param "" Unused parameter (kept for interface compatibility)
     * @param _salt Salt value for address computation
     * @return Computed address of the account
     */
    function computeAddress(
        address,
        uint256 _salt
    ) external view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                _salt,
                                CREATION_CODE_HASH
                            )
                        )
                    )
                )
            );
    }

    /**
     * @dev Function to authorize an upgrade to a new implementation
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
