// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import {IPayableAccount} from "../../interfaces/IPayableAccount.sol";
import {MODULE_TYPE_EXECUTOR} from "../../interfaces/IERC7579Module.sol";
import "../../interfaces/IRecoveryModule.sol";

contract MockRecoveryModule is IRecoveryModule {
    event RecoveryCallbackCalled(bytes _data);

    event OnInstallCalled(bytes _data);
    event OnUninstallCalled(bytes _data);

    function recoverByTimestamp(
        address _account,
        uint256 _timestamp,
        bytes calldata _data
    ) external {
        (address validator, bytes32 pubKeyHash) = abi.decode(
            _data,
            (address, bytes32)
        );
        bytes memory data = abi.encode(
            pubKeyHash,
            _timestamp,
            type(uint128).max
        );
        IPayableAccount(_account).recover(validator, data);
    }

    function claimRecoveryFee(
        address _account,
        address _receiver,
        uint256 _value
    ) external {
        IPayableAccount(_account).claimRecoveryFee(_receiver, _value);
    }

    function recover(address _account, bytes calldata _data) external {
        (address validator, bytes32 pubKeyHash) = abi.decode(
            _data,
            (address, bytes32)
        );

        bytes memory data = abi.encode(
            pubKeyHash,
            block.timestamp,
            type(uint128).max
        );
        IPayableAccount(_account).recover(validator, data);
    }

    function onInstall(bytes calldata data) external {
        emit OnInstallCalled(data);
    }

    function onUninstall(bytes calldata data) external {
        emit OnUninstallCalled(data);
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR;
    }
}
