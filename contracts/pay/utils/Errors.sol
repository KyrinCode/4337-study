// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ChequeStatus} from "../utils/Types.sol";

error InvalidAccount(address account);
error ChequeStatusError(uint256 chequeID, ChequeStatus status);
error ChequeExpired(uint256 chequeID, uint256 deadline, uint256 timestamp);
error ChequeNotExpired(uint256 chequeID, uint256 deadline, uint256 timestamp);
error ClaimAddressError(address to, address caller);
error AccessError(uint256 chequeID, address caller);
error ExpirationTimeNotValid(
    uint128 refundTime,
    uint128 cancelTime,
    uint128 max
);
error ETHAmountError(uint256 required, uint256 received);
error Expired(uint256 expirationTime, uint256 timestamp);
error CancleError();
error ChequeExists(uint256);
error AmountError();
error TokenNotAllowed(address token);
error EnforcedHalt();
error ExpectedHalt();
error InvalidAmount();
error InvalidBundler(address bundler);
error Rejected();
error NotAllowed();
error InvalidToken(address token);
