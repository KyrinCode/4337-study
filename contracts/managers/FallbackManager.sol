// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import {IModule} from "../interfaces/IERC7579Module.sol";

/// @title FallbackManager - Manages fallback handler functionality
/// @notice Handles installation and uninstallation of fallback handlers
contract FallbackManager {
    address public fallbackHandler;

    /// @notice Installs a new fallback handler
    /// @dev Calls onInstall on the handler and stores its address
    /// @param handler Address of the fallback handler to install
    /// @param data Installation data to be passed to the handler
    function _installFallback(address handler, bytes calldata data) internal {
        IModule(handler).onInstall(data);
        fallbackHandler = handler;
    }

    /// @notice Uninstalls the current fallback handler
    /// @dev Calls onUninstall on the handler and removes its address
    /// @param handler Address of the fallback handler to uninstall
    /// @param data Uninstallation data to be passed to the handler
    function _uninstallFallback(address handler, bytes calldata data) internal {
        IModule(handler).onUninstall(data);
        delete fallbackHandler;
    }

    /// @notice Checks if a specific handler is currently installed
    /// @dev Compares the provided handler address with the stored fallback handler
    /// @param handler Address of the handler to check
    /// @return bool True if the handler is installed, false otherwise
    function _isFallbackInstalled(
        address handler
    ) internal view returns (bool) {
        return fallbackHandler == handler;
    }
}
