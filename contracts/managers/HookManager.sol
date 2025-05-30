// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import "../utils/Errors.sol";
import {IHook} from "../interfaces/IERC7579Module.sol";

/// @title Hook Manager for ERC7579 Smart Accounts
/// @notice Manages the installation and uninstallation of execution hooks
/// @dev Provides core functionality for hook lifecycle management
contract HookManager {
    /// @notice The address of the currently installed execution hook
    address public executionHook;

    /// @notice Installs a new execution hook
    /// @dev Calls the hook's onInstall function and stores the hook address
    /// @param _hook The address of the hook to install
    /// @param _data Additional data to pass to the hook's onInstall function
    function _installHook(address _hook, bytes calldata _data) internal {
        IHook(_hook).onInstall(_data);
        executionHook = _hook;
    }

    /// @notice Uninstalls the current execution hook
    /// @dev Calls the hook's onUninstall function and removes the hook address
    /// @param _hook The address of the hook to uninstall
    /// @param _data Additional data to pass to the hook's onUninstall function
    function _uninstallHook(address _hook, bytes calldata _data) internal {
        IHook(_hook).onUninstall(_data);
        delete executionHook;
    }

    /// @notice Checks if a specific hook is currently installed
    /// @dev Compares the provided hook address with the currently installed hook
    /// @param _hook The address of the hook to check
    /// @return True if the hook is installed, false otherwise
    function _isHookInstalled(address _hook) internal view returns (bool) {
        return executionHook == _hook;
    }
}
