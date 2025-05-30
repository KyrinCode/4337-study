// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "@account-abstraction/contracts/interfaces/IPaymaster.sol";

/**
 * @title IBasePaymaster
 * @dev Interface for the base paymaster contract that handles gas payments and user operation validation
 */
interface IBasePaymaster is IPaymaster {
    /**
     * @dev Emitted when a new gas manager is set
     * @param gasManager Address of the new gas manager
     */
    event SetGasManager(address gasManager);

    /**
     * @dev Emitted when a new config is set
     * @param config Address of the new config
     */
    event SetConfig(address config);

    /**
     * @dev Emitted when gas is deposited to the entry point
     * @param entryPoint Address of the entry point
     * @param amount Amount of gas deposited
     */
    event GasDeposited(address entryPoint, uint256 amount);

    /**
     * @dev Emitted when gas is withdrawn from the entry point
     * @param entryPoint Address of the entry point
     * @param recipient Address receiving the withdrawn gas
     * @param amount Amount of gas withdrawn
     */
    event GasWithdrawn(
        address entryPoint,
        address payable recipient,
        uint256 amount
    );

    /**
     * @dev Withdraws gas from the entry point
     * @param recipient Address to receive the withdrawn gas
     * @param amount Amount of gas to withdraw
     */
    function withdrawGas(address payable recipient, uint256 amount) external;

    /**
     * @dev Validates a user operation before it's executed
     * @param userOp The user operation to validate
     * @param userOpHash Hash of the user operation
     * @return context Context bytes to be passed to postOp
     * @return sigTime Signature validation time
     */
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256
    ) external returns (bytes memory context, uint256 sigTime);

    /**
     * @dev Handles post-operation processing
     * @param postOpMode Mode of the post operation
     * @param context Context bytes passed from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost of the operation
     * @param actualUserOpFeePerGas Actual fee per gas for the user operation
     */
    function postOp(
        IPaymaster.PostOpMode postOpMode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external;
}
