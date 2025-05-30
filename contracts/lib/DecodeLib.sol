// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import {AllowFailedExecution} from "../interfaces/internal/ISmartAccountV3.sol";
import {Execution} from "../interfaces/IERC7579Account.sol";

// import {ModeCode} from "./ModeLib.sol";
// import {Session, CallType, PropKeyId} from "../utils/Types.sol";
// import {IHook} from "../interfaces/IERC7579Module.sol";

/**
 * Helper Library for decoding Execution calldata
 * malloc for memory allocation is bad for gas. use this assembly instead
 */
library DecodeLib {
    function decodeInitParams(
        bytes calldata params
    )
        internal
        pure
        returns (
            bytes[] calldata subjects,
            Execution[] calldata executions,
            address validator,
            address eoaSigner
        )
    {
        assembly ("memory-safe") {
            let dataPointer := add(params.offset, calldataload(params.offset))
            subjects.offset := add(dataPointer, 32)
            subjects.length := calldataload(dataPointer)

            dataPointer := add(
                params.offset,
                calldataload(add(params.offset, 32))
            )
            executions.offset := add(dataPointer, 32)
            executions.length := calldataload(dataPointer)

            validator := calldataload(add(params.offset, 0x40))
            eoaSigner := calldataload(add(params.offset, 0x60))
        }
    }

    function decodeBatch(
        bytes calldata callData
    ) internal pure returns (Execution[] calldata executionBatch) {
        /*
         * Batch Call Calldata Layout
         * Offset (in bytes)    | Length (in bytes) | Contents
         * 0x0                  | 0x4               | bytes4 function selector
        *  0x4                  | -                 |
        abi.encode(IERC7579Execution.Execution[])
         */
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            let dataPointer := add(
                callData.offset,
                calldataload(callData.offset)
            )

            // Extract the ERC7579 Executions
            executionBatch.offset := add(dataPointer, 32)
            executionBatch.length := calldataload(dataPointer)
        }
    }

    function decodeSingle(
        bytes calldata executionCalldata
    )
        internal
        pure
        returns (address target, uint256 value, bytes calldata callData)
    {
        target = address(bytes20(executionCalldata[0:20]));
        value = uint256(bytes32(executionCalldata[20:52]));
        callData = executionCalldata[52:];
    }

    function decodeSignature(
        bytes calldata data
    )
        internal
        pure
        returns (
            bytes calldata keys,
            bytes calldata signatures,
            uint256 validationData
        )
    {
        assembly ("memory-safe") {
            let dataPointer := add(data.offset, calldataload(data.offset))
            keys.offset := add(dataPointer, 32)
            keys.length := calldataload(dataPointer)

            dataPointer := add(data.offset, calldataload(add(data.offset, 32)))
            signatures.offset := add(dataPointer, 32)
            signatures.length := calldataload(dataPointer)

            dataPointer := add(data.offset, 0x40)
            validationData := calldataload(dataPointer)
        }
    }
}
