// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IHaltable {
    function halted() external view returns (bool);

    event HaltStatus(uint256 status);
}
