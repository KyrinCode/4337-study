// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {CHALLENGE_LOCATION} from "../utils/Constants.sol";
import {DecodeLib} from "../lib/DecodeLib.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ModeLib} from "../lib/ModeLib.sol";
import {IPayableAccount} from "../interfaces/IPayableAccount.sol";

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {WebAuthn} from "../modules/utils/WebAuthn.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import {Execution} from "../interfaces/IERC7579Account.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {UserOperationLib} from "@account-abstraction/contracts/core/UserOperationLib.sol";
import {P256} from "../modules/utils/P256.sol";
import {AccountProxy} from "../AccountProxy.sol";
import {IConfig} from "../interfaces/IConfig.sol";
import "../utils/Types.sol";

contract Helper {
    using UserOperationLib for PackedUserOperation;

    function encodePacked(
        address factory,
        bytes memory initializer
    ) external pure returns (bytes memory) {
        return abi.encodePacked(factory, initializer);
    }

    function getUserOpHashWithEntryPoint(
        address entryPoint,
        uint256 chainid,
        PackedUserOperation calldata userOp
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(userOp.hash(), entryPoint, chainid));
    }

    function getAccountInitializer2(
        uint256 pubKeyX,
        uint256 pubKeyY,
        address validator,
        address eoaSigner,
        address target,
        bytes calldata targetData,
        bytes calldata targetData1
    ) public pure returns (bytes memory, bytes memory) {
        bytes32 pubKeyHash = keccak256(abi.encode([pubKeyX, pubKeyY]));
        uint128 validFrom = 0;
        uint128 validUntil = type(uint128).max;
        bytes memory subject = abi.encode(pubKeyHash, validFrom, validUntil);

        bytes[] memory subjects = new bytes[](1);
        subjects[0] = subject;

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution(target, 0, targetData);
        executions[1] = Execution(target, 0, targetData1);

        bytes memory initializeCalldata = abi.encode(
            subjects,
            executions,
            validator,
            eoaSigner
        );
        bytes memory initializer = abi.encodeCall(
            IPayableAccount.initialize,
            initializeCalldata
        );
        return (initializer, initializeCalldata);
    }

    function getPubkeyHash(
        uint256 pubKeyX,
        uint256 pubKeyY
    ) public pure returns (bytes32, bytes memory) {
        bytes32 hash = keccak256(abi.encode([pubKeyX, pubKeyY]));
        bytes memory encodeHash = abi.encode(hash);
        return (hash, encodeHash);
    }

    function getFactoryCreateAccountHash(
        address factory,
        uint256 _salt,
        uint256 expireTime,
        bytes memory _initializer
    ) external view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    block.chainid,
                    factory,
                    _initializer,
                    _salt,
                    expireTime
                )
            );
    }

    function getConfigSetSignerHash(
        address config,
        address sender,
        address eoaSigner,
        uint256 expireTime
    ) external pure returns (bytes32) {
        return keccak256(abi.encode(config, sender, eoaSigner, expireTime));
    }

    function getSharelinkHash(
        address payAddress,
        uint256 chequeID,
        uint256 recipientAddress,
        uint256 expireTime
    ) external view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    block.chainid,
                    payAddress,
                    chequeID,
                    recipientAddress,
                    expireTime
                )
            );
    }

    function getPackedSig(
        uint256 expireTime,
        bytes memory sig
    ) external pure returns (bytes memory) {
        return abi.encodePacked(abi.encode(expireTime), sig);
    }

    function getBlocktimeStamp() external view returns (uint256) {
        return block.timestamp;
    }

    function encodeUopHash(
        bytes32 uopHash,
        uint256 expireTime
    ) external pure returns (bytes32) {
        return keccak256(abi.encode(uopHash, expireTime));
    }

    function PasskeyFormatDemo(
        bytes32 uid,
        bytes memory okxSignatureData
    ) external pure returns (bytes memory signature) {
        bytes memory hookData = abi.encode("hookData");
        bytes
            memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97631900000000";
        string
            memory clientDataJSON = '{"type":"webauthn.get","challenge":"cTSBSUog_7MP1UEQwtKpyOGLieSK0pCdOk-G9jQOk_E","origin":"http://localhost:8000","crossOrigin":false}';
        uint256 r = 57836264558064086639020112780203680029268191869080438693024908366638138886553;
        uint256 s = 15346654131055733073592155278397210040790853340746806712611125160274124719177;
        uint256 _pubKeyX = 9000124022834614200256284929030969105094198715369715968668111708329684394834;
        uint256 _pubKeyY = 11616117864748518373354356856885570927773036872740570569730893894816993406543;
        bytes memory userSignatureData = abi.encode(
            authenticatorData,
            clientDataJSON,
            1,
            r,
            s,
            _pubKeyX,
            _pubKeyY,
            false
        );

        /// encode the two signatures
        signature = abi.encode(
            hookData, // bytes calldata hookData,
            abi.encode(userSignatureData, okxSignatureData), // bytes calldata signature,
            abi.encode(uid)
        );
    }

    function getSignature2(
        uint256 pubKeyX,
        uint256 pubKeyY,
        bytes memory passkeySig,
        bytes memory eoaSignature,
        uint256 validationData
    ) external pure returns (bytes memory) {
        bytes memory pubKey = abi.encode([pubKeyX, pubKeyY]);
        return
            abi.encode(
                pubKey,
                abi.encode(passkeySig, eoaSignature),
                validationData
            );
    }

    function getSignature2Decode(
        bytes calldata sig
    ) external pure returns (bytes memory, bytes memory, uint256) {
        return abi.decode(sig, (bytes, bytes, uint256));
    }

    function dealData(
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 dataHash
    ) external pure returns (bytes memory okxSignatureData, bytes memory sig) {
        okxSignatureData = abi.encode(dataHash, abi.encodePacked(r, s, v));
        sig = abi.encodePacked(r, s, v);
    }

    function mockRecover(
        bytes memory okxSignatureData
    ) external pure returns (address) {
        (bytes32 okxHash, bytes memory okxSignature) = abi.decode(
            okxSignatureData,
            (bytes32, bytes)
        );
        bytes32 signedHash = MessageHashUtils.toEthSignedMessageHash(okxHash);
        address okxSigner = ECDSA.recover(signedHash, okxSignature);
        return okxSigner;
    }

    function recoverAddress(
        bytes memory signature,
        bytes32 hash
    ) external pure returns (address) {
        bytes32 signedHash = MessageHashUtils.toEthSignedMessageHash(hash);
        return ECDSA.recover(signedHash, signature);
    }

    function recoverAddress1(
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 hash
    ) external pure returns (address) {
        return ECDSA.recover(hash, v, r, s);
    }

    function getHash(string memory data) external pure returns (bytes32) {
        return MessageHashUtils.toEthSignedMessageHash(bytes(data));
    }

    function getHash1(bytes32 hash) external pure returns (bytes32) {
        return MessageHashUtils.toEthSignedMessageHash(hash);
    }

    function splitSig(
        bytes memory signature
    ) external pure returns (bytes32, bytes32, uint8) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        /// @solidity memory-safe-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        return (r, s, v);
    }

    function getClientJson(
        string memory clientDataJSONPre,
        string memory clientDataJSONPost,
        bytes32 userOpHash
    )
        external
        pure
        returns (
            string memory clientDataJSON,
            bytes memory message,
            bytes32 messageHash
        )
    {
        string memory challengeB64url = Base64.encodeURL(
            abi.encodePacked(userOpHash)
        );

        clientDataJSON = string.concat(
            clientDataJSONPre,
            challengeB64url,
            clientDataJSONPost
        );
        bytes
            memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97631900000000";

        bytes32 clientDataHash = sha256(bytes(clientDataJSON));

        message = bytes.concat(authenticatorData, clientDataHash);
        messageHash = sha256(message);
    }

    // /// decode the WebAuthn signature
    // (
    //     bytes memory authenticatorData,
    //     string memory clientDataJSON,
    //     uint256 responseTypeLocation,
    //     uint256 r,
    //     uint256 s,
    //     uint8 usePrecompiled
    // ) = abi.decode(
    //         userSignature,
    //         (bytes, string, uint256, uint256, uint256, uint8)
    //     );
    function encodePasskeySig(
        uint256 r,
        uint256 s,
        VerifierType verifyType,
        string memory clientDataJSON
    ) external pure returns (bytes memory) {
        bytes
            memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97631900000000";
        ///string
        ///    memory clientDataJSON = '{"type":"webauthn.get","challenge":"gw6YFSEOxfTvfP937iQt2nslHwbUYHOoKLKBhq2RLFM","origin":"http://localhost:8000","crossOrigin":false}';
        return
            abi.encode(authenticatorData, clientDataJSON, 1, r, s, verifyType);
    }

    function passkeyVerify(
        bytes32 okxHash,
        uint256 r,
        uint256 s,
        uint256 x,
        uint256 y,
        VerifierType verifyType,
        string memory clientDataJSON
    ) external view returns (bool, uint256) {
        uint256 gasBefore = gasleft();
        bytes
            memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97631900000000";
        ///string
        ///    memory clientDataJSON = '{"type":"webauthn.get","challenge":"gw6YFSEOxfTvfP937iQt2nslHwbUYHOoKLKBhq2RLFM","origin":"http://localhost:8000","crossOrigin":false}';
        bool verified = WebAuthn.verifySignature(
            abi.encodePacked(okxHash),
            authenticatorData,
            false,
            clientDataJSON,
            CHALLENGE_LOCATION,
            1,
            r,
            s,
            x,
            y,
            verifyType
        );
        uint256 gasUsed = gasBefore - gasleft();
        return (verified, gasUsed);
    }

    function passkeyVerify1(
        bytes32 messageHash,
        uint256 r,
        uint256 s,
        uint256 x,
        uint256 y,
        VerifierType verifier
    ) external view returns (bool) {
        bool verified = P256.verifySignature(messageHash, r, s, x, y, verifier);
        return verified;
    }

    function verifyPasskeySignature(
        bytes memory challenge,
        bytes memory authenticatorData,
        string memory clientDataJSON,
        uint256 r,
        uint256 s,
        uint256 x,
        uint256 y,
        VerifierType verifier
    ) external view returns (bool, uint256) {
        uint256 gasBefore = gasleft();
        bool verified = WebAuthn.verifySignature(
            challenge,
            authenticatorData,
            false,
            clientDataJSON,
            CHALLENGE_LOCATION,
            1,
            r,
            s,
            x,
            y,
            verifier
        );
        uint256 gasUsed = gasBefore - gasleft();
        return (verified, gasUsed);
    }

    function checkValidationDate(
        uint256 validationData
    ) external view returns (address, bool) {
        (address aggregator, bool outOfTimeRange) = _getValidationData(
            validationData
        );
        return (aggregator, outOfTimeRange);
    }

    function _getValidationData(
        uint256 validationData
    ) internal view returns (address aggregator, bool outOfTimeRange) {
        if (validationData == 0) {
            return (address(0), false);
        }
        ValidationData memory data = _parseValidationData(validationData);
        // solhint-disable-next-line not-rely-on-time
        outOfTimeRange =
            block.timestamp > data.validUntil ||
            block.timestamp < data.validAfter;
        aggregator = data.aggregator;
    }

    function parseValidationData(
        uint256 validationData
    ) external pure returns (ValidationData memory data) {
        address aggregator = address(uint160(validationData));
        uint48 validUntil = uint48(validationData >> 160);
        if (validUntil == 0) {
            validUntil = type(uint48).max;
        }
        uint48 validAfter = uint48(validationData >> (48 + 160));
        return ValidationData(aggregator, validAfter, validUntil);
    }

    function getValidationData(
        uint256 validationData
    ) external pure returns (uint256) {
        return validationData << 160;
    }

    function packValidationData(
        address aggregator,
        uint256 validUntil,
        uint256 validAfter
    ) external pure returns (uint256) {
        return
            uint160(aggregator) |
            (validUntil << 160) |
            (validAfter << (160 + 48));
    }

    function computePredictionHash() external pure returns (bytes32) {
        return keccak256(abi.encodePacked(type(AccountProxy).creationCode));
    }
}
