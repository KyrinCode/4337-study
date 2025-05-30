// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import "../../interfaces/IERC7579Module.sol";
import "../../interfaces/IConfig.sol";

import "../utils/WebAuthn.sol";
import "../../utils/Constants.sol";
import "../../utils/Errors.sol";

/**
 * @title WebAuthnAndECDSAValidator
 * @dev A validator contract that combines WebAuthn (passkey) and ECDSA signature verification
 */
contract WebAuthnAndECDSAValidator is IStatelessValidator {
    /**
     * @dev Reference to the configuration contract
     */
    IConfig public immutable CONFIG;

    /**
     * @dev Initializes the validator with a configuration contract
     * @param config Address of the configuration contract
     */
    constructor(IConfig config) {
        CONFIG = config;
    }

    /**
     * @dev Verifies the provided signature against the hash
     * @param signatureHash Hash of the message to verify
     * @param signature Combined WebAuthn and EOA signatures
     * @param data Public key data for verification
     * @return bytes4 Magic value if signature is valid, invalid value otherwise
     */
    function validateSignatureWithData(
        bytes32 signatureHash,
        bytes calldata signature,
        bytes calldata data
    ) external view returns (bool) {
        return _verifySignature(signatureHash, signature, data);
    }

    /**
     * @dev Internal function to verify both WebAuthn and ECDSA signatures
     * @param signatureHash Hash of the message to verify
     * @param signature Combined WebAuthn and EOA signatures
     * @param pubkey Public key data for WebAuthn verification
     * @return bool True if both signatures are valid
     */
    function _verifySignature(
        bytes32 signatureHash,
        bytes calldata signature,
        bytes calldata pubkey
    ) private view returns (bool) {
        uint256 _pubKeyX = uint256(bytes32(pubkey[:32]));
        uint256 _pubKeyY = uint256(bytes32(pubkey[32:64]));
        // decode the signatures
        (bytes memory userSignature, bytes memory eoaSignature) = abi.decode(
            signature,
            (bytes, bytes)
        );

        /// decode the WebAuthn signature
        (
            bytes memory authenticatorData,
            string memory clientDataJSON,
            uint256 responseTypeLocation,
            uint256 r,
            uint256 s,
            VerifierType verifier
        ) = abi.decode(
                userSignature,
                (bytes, string, uint256, uint256, uint256, VerifierType)
            );
        if (!CONFIG.isWhitelistedVerifier(verifier)) revert InvalidVerifier();

        bytes32 signedHash = MessageHashUtils.toEthSignedMessageHash(
            signatureHash
        );
        address eoaSigner = ECDSA.recover(signedHash, eoaSignature);
        // Verify the signature
        bool isValidSigner = CONFIG.walletSigner(msg.sender) == eoaSigner;
        bool isValidPasskey = WebAuthn.verifySignature(
            abi.encodePacked(signatureHash),
            authenticatorData,
            false,
            clientDataJSON,
            CHALLENGE_LOCATION,
            responseTypeLocation,
            r,
            s,
            _pubKeyX,
            _pubKeyY,
            verifier
        );
        return isValidSigner && isValidPasskey;
    }

    /**
     * @dev Checks if this module is a validator type
     * @param moduleTypeId The type ID to check
     * @return bool True if the module type matches validator type
     */
    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_STATELESS_VALIDATOR;
    }
}
