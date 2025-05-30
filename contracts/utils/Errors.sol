// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import "../lib/ModeLib.sol";

error UnsupportedModule(uint256 typeId);
error UnsupportedExecType(ExecType execType);
error UnsupportedCallType(CallType callType);
error NotFromEntryPoint();
error NotFromEntryPointOrSelf();
error InvalidBundler();
error InvalidPubKey();
error InvalidModule();
error InvalidValidator();
error InvalidValidatorSession();
error InvalidExecutor();
error InvalidRecoveryModule();
error InvalidSignature();
error InvalidFallbackHandler();
error MaximumKeysExceeded();
error Expired(uint256 expirationTime, uint256 blocktime);
error LengthNotMatch();
error InvalidAddress();
error RemovingLastKey();
error InvalidSingleton(address singleton);
error AccountCreationFailed(string result);
error WalletInitialized();
error NotAllowed();
error InvalidNode();
error InvalidVerifier();

// Paymaster Errors
error NotFromSupportedEntryPoint(address entryPoint);
