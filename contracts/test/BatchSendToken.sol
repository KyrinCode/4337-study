// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TransferHelper, NATIVE_ETH} from "../pay/TransferHelper.sol";

contract BatchSendToken is Ownable {

    using TransferHelper for address;

    uint256 public amount = 1;

    constructor() Ownable(msg.sender) {}

    receive() payable external {}

    function takeback(address tokenAddress, address payable to) external onlyOwner {
        uint256 balance;
        if (tokenAddress == NATIVE_ETH) {
            balance = address(this).balance;
        } else {
            balance = IERC20(tokenAddress).balanceOf(address(this));
        }
        tokenAddress.tokenTransfer(to, balance);
    }

    function batchSend(address payable[] calldata addrs, address tokenAddress) external onlyOwner {
        uint256 count = addrs.length;
        for (uint256 i; i < count; ) {
           tokenAddress.tokenTransfer(addrs[i], amount);
            unchecked {
                ++i;
            }
        }
    }

    function setAmount(uint256 newAmount) external onlyOwner {
        amount = newAmount;
    }
}
