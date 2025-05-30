// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../interfaces/IERC7579Module.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
/**
 * @dev Contract that handles token receiving functionality, implementing both IERC165 and IModule interfaces.
 * Supports ERC721 and ERC1155 token receiving through standard interfaces.
 */
contract TokenReceiver is IERC165, IModule {
    /**
     * @dev Called when the module is installed
     * @param data Installation data (unused)
     */
    function onInstall(bytes calldata data) external pure {}

    /**
     * @dev Called when the module is uninstalled
     * @param data Uninstallation data (unused)
     */
    function onUninstall(bytes calldata data) external pure {}

    /**
     * @dev Checks if the module supports a specific module type
     * @param moduleTypeId The ID of the module type to check
     * @return bool True if the moduleTypeId matches MODULE_TYPE_FALLBACK
     */
    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_FALLBACK;
    }

    /**
     * @dev Implementation of IERC165 interface detection
     * @param interfaceId The interface identifier to check
     * @return bool True if the contract supports the interface
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external view virtual override returns (bool) {
        // 0x150b7a02: `onERC721Received(address,address,uint256,bytes)`.
        // 0xf23a6e61: `onERC1155Received(address,address,uint256,uint256,bytes)`.
        // 0xbc197c81: `onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)`.
        return
            interfaceId == 0x150b7a02 ||
            interfaceId == 0xf23a6e61 ||
            interfaceId == 0xbc197c81 ||
            interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {}

    /**
     * @dev Fallback function that handles token receiving callbacks
     * Returns the function selector for ERC721 and ERC1155 token receiving functions
     */
    fallback() external payable {
        assembly {
            let s := shr(224, calldataload(0))
            // 0x150b7a02: `onERC721Received(address,address,uint256,bytes)`.
            // 0xf23a6e61: `onERC1155Received(address,address,uint256,uint256,bytes)`.
            // 0xbc197c81: `onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)`.
            if or(eq(s, 0x150b7a02), or(eq(s, 0xf23a6e61), eq(s, 0xbc197c81))) {
                mstore(0x20, s) // Store `msg.sig`.
                return(0x3c, 0x20) // Return `msg.sig`.
            }
        }

        revert();
    }
}
