// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IHaltable} from "./interfaces/IHaltable.sol";
import {EnforcedHalt, ExpectedHalt} from "./utils/Errors.sol";

contract Haltable is IHaltable {
    // Using uint8 for gas efficiency since we only need two states
    uint8 private constant NOT_HALTED = 1;
    uint8 private constant HALTED = 2;

    // Current halt status, initialized to NOT_HALTED
    uint8 haltStatus = NOT_HALTED;

    constructor() {}

    /// @notice Modifier to restrict function execution to when contract is not halted
    /// @dev Throws EnforcedHalt if contract is halted
    modifier whenNotHalted() {
        if (haltStatus == HALTED) revert EnforcedHalt();
        _;
    }

    /// @notice Modifier to restrict function execution to when contract is halted
    /// @dev Throws ExpectedHalt if contract is not halted
    modifier whenHalted() {
        if (haltStatus == NOT_HALTED) revert ExpectedHalt();
        _;
    }

    /// @notice Internal function to halt the contract
    /// @dev Can only be called when contract is not halted
    /// @dev Emits HaltStatus event
    /// @dev Virtual to allow override in derived contracts
    function _halt() internal virtual whenNotHalted {
        haltStatus = HALTED;
        emit HaltStatus(haltStatus);
    }

    /// @notice Internal function to unhalt the contract
    /// @dev Can only be called when contract is halted
    /// @dev Emits HaltStatus event
    /// @dev Virtual to allow override in derived contracts
    function _unhalt() internal virtual whenHalted {
        haltStatus = NOT_HALTED;
        emit HaltStatus(haltStatus);
    }

    /// @notice External view function to check if contract is halted
    /// @return bool True if contract is halted, false otherwise
    function halted() external view returns (bool) {
        return haltStatus == HALTED;
    }
}
