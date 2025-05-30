// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title OracleTimelockController
 * @dev A custom TimelockController that disallows delay updates.
 * @notice This contract extends OpenZeppelin's TimelockController and overrides the updateDelay function.
 */
contract OracleTimelockController is TimelockController {
    /**
     * @dev Custom error for unsupported delay updates.
     */
    error UpdateDelayUnsupported();

    /**
     * @dev Constructor for OracleTimelockController.
     * @param minDelay The minimum delay for timelock operations.
     * @param proposers An array of addresses that can propose timelock operations.
     * @param executors An array of addresses that can execute timelock operations.
     * @param admin The address of the admin.
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}

    /**
     * @dev Overrides the updateDelay function to prevent delay updates.
     * @param newDelay The new delay value (unused).
     * @notice This function always reverts with UpdateDelayUnsupported error.
     */
    function updateDelay(uint256 newDelay) external pure override {
        revert UpdateDelayUnsupported();
    }
}
