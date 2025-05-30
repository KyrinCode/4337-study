// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Helper library for external contracts to verify P256 signatures.
 *
 */
import "../../utils/Types.sol";

library P256 {
    address constant P256_VERIFIER = 0xc2b78104907F722DABAc4C69f826a522B2754De4;
    address constant PRECOMPILED_VERIFIER =
        0x0000000000000000000000000000000000000100;
    address constant ELLIPTIC_CURVE =
        0x5EF35Bc6ddb6425A0d43408D7810c3B3180aB58A;
    bytes4 constant VALIDATE_SIGNATURE_SELECTOR = 0x04e960d7;

    function verifySignatureAllowMalleability(
        bytes32 message_hash,
        uint256 r,
        uint256 s,
        uint256 x,
        uint256 y,
        VerifierType verifier
    ) internal view returns (bool) {
        bytes memory args = abi.encode(message_hash, r, s, x, y);
        if (verifier == VerifierType.PRECOMPILED_VERIFIER) {
            (bool success, bytes memory ret) = PRECOMPILED_VERIFIER.staticcall(
                args
            );
            if (success == false || ret.length == 0) {
                return false;
            }
            return abi.decode(ret, (uint256)) == 1;
        } else if (verifier == VerifierType.P256_VERIFIER) {
            (, bytes memory ret) = P256_VERIFIER.staticcall(args);
            return abi.decode(ret, (uint256)) == 1;
        } else {
            (, bytes memory ret) = ELLIPTIC_CURVE.staticcall(
                abi.encodeWithSelector(
                    VALIDATE_SIGNATURE_SELECTOR,
                    message_hash,
                    [r, s],
                    [x, y]
                )
            );
            return abi.decode(ret, (uint256)) == 1;
        }
    }

    /// P256 curve order n/2 for malleability check
    uint256 constant P256_N_DIV_2 =
        57896044605178124381348723474703786764998477612067880171211129530534256022184;

    function verifySignature(
        bytes32 message_hash,
        uint256 r,
        uint256 s,
        uint256 x,
        uint256 y,
        VerifierType verifier
    ) internal view returns (bool) {
        // check for signature malleability
        if (s > P256_N_DIV_2) {
            return false;
        }
        return
            verifySignatureAllowMalleability(
                message_hash,
                r,
                s,
                x,
                y,
                verifier
            );
    }
}
