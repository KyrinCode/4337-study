// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import "../interfaces/IERC7579Account.sol";
import "../lib/DecodeLib.sol";
import "../lib/ModeLib.sol";
import "../utils/Errors.sol";
import {IHook, IModule} from "../interfaces/IERC7579Module.sol";

contract ExecutionManager {
    using ModeLib for ModeCode;
    using DecodeLib for bytes;

    event TryExecuteUnsuccessful(uint256 batchExecutionindex, bytes result);

    mapping(address => bool) public executors;

    function _installExecutor(
        address module,
        bytes calldata initData
    ) internal {
        IModule(module).onInstall(initData);
        executors[module] = true;
    }

    function _uninstallExecutor(address module, bytes calldata data) internal {
        IModule(module).onUninstall(data);
        delete executors[module];
    }

    function _isExecutorInstalled(address module) internal view returns (bool) {
        return executors[module];
    }

    // ------ manage execution ------
    function _execute(
        address hook,
        ModeCode mode,
        bytes calldata executionCalldata
    ) internal returns (bytes[] memory returnData) {
        (
            CallType callType,
            ExecType execType,
            ModeSelector modeSelector,
            ModePayload modePayload
        ) = mode.decode();

        if (callType == CALLTYPE_BATCH)
            return
                _handleBatchExecution(
                    hook,
                    execType,
                    modeSelector,
                    executionCalldata.decodeBatch(),
                    modePayload
                );

        if (callType == CALLTYPE_SINGLE) {
            (
                address target,
                uint256 value,
                bytes calldata callData
            ) = executionCalldata.decodeSingle();

            return
                _handleSingleExecution(hook, execType, target, value, callData);
        }

        revert UnsupportedCallType(callType);
    }

    function _handleSingleExecution(
        address hook,
        ExecType execType,
        address target,
        uint256 value,
        bytes calldata callData
    ) internal returns (bytes[] memory result) {
        result = new bytes[](1);
        bool success;
        (success, result[0]) = hook == address(0)
            ? _tryExecute(target, value, callData)
            : _tryExecuteWithHook(hook, target, value, callData);

        if (execType == EXECTYPE_DEFAULT) {
            if (!success) {
                bytes memory mRes = result[0];
                assembly {
                    revert(add(mRes, 0x20), mload(mRes))
                }
            }
        } else if (execType == EXECTYPE_TRY) {
            if (!success) emit TryExecuteUnsuccessful(0, result[0]);
        } else revert UnsupportedExecType(execType);

        return result;
    }

    function _handleBatchExecution(
        address hook,
        ExecType execType,
        ModeSelector,
        Execution[] calldata executions,
        ModePayload
    ) internal returns (bytes[] memory result) {
        uint256 length = executions.length;
        result = new bytes[](length);

        for (uint256 i = 0; i < length; ) {
            Execution calldata _exec = executions[i];

            (bool success, bytes memory _result) = hook == address(0)
                ? _tryExecute(_exec.target, _exec.value, _exec.callData)
                : _tryExecuteWithHook(
                    hook,
                    _exec.target,
                    _exec.value,
                    _exec.callData
                );

            if (execType == EXECTYPE_DEFAULT) {
                if (!success) {
                    assembly {
                        revert(add(_result, 0x20), mload(_result))
                    }
                }
            } else if (execType == EXECTYPE_TRY) {
                if (!success) emit TryExecuteUnsuccessful(i, _result);
            } else revert UnsupportedExecType(execType);

            result[i] = _result;

            unchecked {
                ++i;
            }
        }
    }

    function _tryExecuteWithHook(
        address hook,
        address target,
        uint256 value,
        bytes calldata callData
    ) internal returns (bool success, bytes memory result) {
        bytes memory hookData = IHook(hook).preCheck(target, value, callData);
        (success, result) = _tryExecute(target, value, callData);
        IHook(hook).postCheck(hookData);
    }

    function _tryExecute(
        address target,
        uint256 value,
        bytes calldata callData
    ) internal returns (bool success, bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            calldatacopy(result, callData.offset, callData.length)
            success := call(
                gas(),
                target,
                value,
                result,
                callData.length,
                codesize(),
                0x00
            )
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }
}
