// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import {IMPLEMENTATION_SLOT} from "./utils/Constants.sol";
import "./utils/Errors.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

/**
 * @title AccountProxy
 * @dev A proxy contract that delegates calls to an implementation contract.
 * This contract follows the proxy pattern to enable upgradeable smart contracts.
 */
contract AccountProxy {
    /**
     * @dev Constructor function
     */
    constructor() {}

    /**
     * @dev Fallback function for receiving Ether
     * Delegates the call to the implementation contract
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function for non-matching function signatures
     * Delegates the call to the implementation contract
     */
    fallback() external {
        _fallback();
    }

    /**
     * @dev Initializes the proxy with an implementation contract and runs the initializer
     * @param _implementation Address of the implementation contract
     * @param _initializer Calldata for the initialization function
     * @notice Can only be called once when implementation is not set
     * @custom:throws WalletInitialized if the implementation is already set
     * @custom:throws AccountCreationFailed if the initialization fails
     */
    function initialize(
        address _implementation,
        bytes calldata _initializer
    ) external {
        if (StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value != address(0))
            revert WalletInitialized();

        assembly ("memory-safe") {
            sstore(IMPLEMENTATION_SLOT, _implementation)
        }

        /// @custom:oz-upgrades-unsafe-allow delegatecall
        (bool success, bytes memory result) = _implementation.delegatecall(
            _initializer
        );
        if (!success) revert AccountCreationFailed(string(result));
    }

    /**
     * @dev Internal fallback function that handles the delegation of calls
     * @notice Forwards all transactions to the implementation contract and returns all received return data
     * @custom:assembly Uses assembly for efficient delegation and return data handling
     */
    function _fallback() internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(
                gas(),
                sload(IMPLEMENTATION_SLOT),
                0,
                calldatasize(),
                0,
                0
            )
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}
