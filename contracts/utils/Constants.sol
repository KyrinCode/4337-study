// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

// Bit flag indicating signature validation failure
// Left shift 1 by 96 bits
uint256 constant SIG_VALIDATION_FAILED = 1 << 96;

// Magic value for EIP-1271 signature validation
// Returns this value when signature is valid
bytes4 constant MAGIC_VALUE = 0x1626ba7e;

// Invalid signature return value
// Returns this value when signature is invalid
bytes4 constant INVALID_VALUE = 0xffffffff;

// Storage key for initialization status
// Used to track if a contract has been initialized
bytes32 constant INITIALIZED_KEY = 0x000;

// Storage slot for proxy implementation address
// EIP-1967 implementation slot
bytes32 constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

// Special address to indicate hook skipping
// Uses address(1) as a sentinel value
address constant SKIP_ADDRESS = address(1);

// Identifier for payable account functionality
// Used as a feature identifier string
string constant PAYABLE_ACCOUNT = "okx.account.pay";

// Position of the challenge in storage
// Used for challenge-response verification
uint256 constant CHALLENGE_LOCATION = 23;
