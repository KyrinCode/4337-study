// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import {IModule} from "./IERC7579Module.sol";

/// @title Recovery Module Interface for ERC7579 Account
/// @notice Interface for modules that handle account recovery functionality
interface IRecoveryModule is IModule {
    /// @notice Recovers an account using the provided recovery data
    /// @dev This function should implement the recovery logic specific to the module
    /// @param _account Address of the account to recover
    /// @param _data Recovery-specific data required for the recovery process
    function recover(address _account, bytes calldata _data) external;
}
