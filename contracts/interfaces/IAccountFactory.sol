// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

/**
 * @title Account Factory Interface
 * @notice Interface for creating and managing smart contract accounts
 * @dev Defines core functionality for account creation and validation
 */
interface IAccountFactory {
    /**
     * @notice Emitted when a new account is created
     * @dev Logs the creation of a new account with its parameters
     * @param account The address of the created account
     * @param _implementation The implementation contract address
     * @param _initializer The initialization data
     * @param _salt The salt value used in account creation
     */
    event AccountCreated(
        address indexed account,
        address _implementation,
        bytes _initializer,
        uint256 _salt
    );

    /**
     * @notice Creates a new account
     * @dev Deploys a new account using the provided implementation and initializer
     * @param _implementation The implementation contract address
     * @param _initializer The initialization data for the account
     * @param _salt The salt value to determine the account address
     * @return The address of the created account
     */
    function createAccount(
        address _implementation,
        bytes calldata _initializer,
        uint256 _salt
    ) external returns (address);

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
    ) external returns (address);

    /**
     * @notice Computes the address of an account before deployment
     * @dev Calculates deterministic address based on implementation and salt
     * @param _implementation The implementation contract address
     * @param _salt The salt value to determine the account address
     * @return The computed address of the account
     */
    function computeAddress(
        address _implementation,
        uint256 _salt
    ) external view returns (address);

    /**
     * @notice Checks if an address is a valid account
     * @dev Verifies if the given address was created by this factory
     * @param account The address to check
     * @return True if the address is a valid account, false otherwise
     */
    function isValidAccount(address account) external view returns (bool);
}
