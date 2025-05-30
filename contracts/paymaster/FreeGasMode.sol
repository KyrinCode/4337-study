// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./BaseMode.sol";

/**
 * @title FreeGasMode
 * @dev Contract that implements free gas mode functionality for paymaster operations
 */
contract FreeGasMode is BaseMode {
    /**
     * @dev Initializes the FreeGasMode contract
     * @param _owner Address of the contract owner
     * @param _entryPoint Address of the entry point contract
     * @param _config Address of the configuration contract
     */
    constructor(
        address _owner,
        address _entryPoint,
        address _config
    ) BaseMode(_owner, _entryPoint, _config) {}

    /**
     * @dev Validates a user operation in Free Gas Mode
     * @param userOpHash Hash of the user operation (unused)
     * @param requiredPreFund Required pre-fund amount (unused)
     * @return context Empty bytes array for post-operation
     * @return validationData 0 if valid, otherwise SIG_VALIDATION_FAILED
     */
    function validatePaymasterUserOp(
        PackedUserOperation calldata,
        bytes32 userOpHash,
        uint256 requiredPreFund
    )
        external
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        bool txValidate = _isWhitelistedBundler();
        return txValidate ? (bytes(""), 0) : (bytes(""), SIG_VALIDATION_FAILED);
    }

    /**
     * @dev Handles post-operation processing (intentionally empty)
     * @param postOpMode Mode of the post-operation
     * @param context Context data from the validation phase
     * @param actualGasCost Actual gas cost of the operation
     * @param actualUserOpFeePerGas Actual fee per gas for the user operation
     */
    function postOp(
        IPaymaster.PostOpMode postOpMode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external override {
        // No post-operation logic needed
    }

    /**
     * @dev Receives ETH and deposits it as gas
     */
    receive() external payable override {
        depositGas(msg.value);
    }
}
