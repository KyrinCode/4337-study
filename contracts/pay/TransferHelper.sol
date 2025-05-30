// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils/Constant.sol";

library TransferHelper {
    using SafeERC20 for IERC20;

    /// @notice Transfers tokens (ETH or ERC20) to a specified address
    /// @param tokenAddress The address of the token (NATIVE_ETH for ETH)
    /// @param to The recipient address
    /// @param amount The amount to transfer
    function tokenTransfer(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal {
        if (tokenAddress == NATIVE_ETH) {
            (bool success, ) = to.call{value: amount}(new bytes(0));
            require(success, "STE");
        } else {
            IERC20(tokenAddress).safeTransfer(to, amount);
        }
    }

    /// @notice Transfers tokens from one address to another using transferFrom
    /// @param tokenAddress The ERC20 token address
    /// @param from The sender address
    /// @param to The recipient address
    /// @param amount The amount to transfer
    function tokenTransferFrom(
        address tokenAddress,
        address from,
        address to,
        uint256 amount
    ) internal {
        IERC20(tokenAddress).safeTransferFrom(from, to, amount);
    }
}
