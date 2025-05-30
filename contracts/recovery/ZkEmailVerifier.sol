// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Groth16Verifier} from "./ZkEmailGroth16Verifier.sol";
import {IZkEmailVerifier} from "../interfaces/IZkEmailVerifier.sol";

contract ZkEmailVerifier is
    UUPSUpgradeable,
    OwnableUpgradeable,
    Groth16Verifier,
    IZkEmailVerifier
{
    /**
     * @notice Constant defining number of domain fields in ZK proof
     */
    uint256 private constant DOMAIN_FIELDS = 9;

    /**
     * @notice Constant defining maximum domain bytes length
     */
    uint256 private constant DOMAIN_BYTES = 255;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
    }

    function verify(
        address _account,
        address _validator,
        bytes32 _newPubKeyHash,
        bytes calldata _proof
    ) external view returns (bool, bytes32, bytes32, uint256, string memory) {
        (
            bytes32 emailHash,
            bytes32 dkimKeyHash,
            bytes32 nullifier,
            uint256 timestamp,
            string memory domain,
            bytes memory proof
        ) = abi.decode(
                _proof,
                (bytes32, bytes32, bytes32, uint256, string, bytes)
            );

        (
            uint256[2] memory pA,
            uint256[2][2] memory pB,
            uint256[2] memory pC
        ) = abi.decode(proof, (uint256[2], uint256[2][2], uint256[2]));
        uint256[17] memory pubSignals = _genPubSignal(
            _account,
            _validator,
            _newPubKeyHash,
            emailHash,
            dkimKeyHash,
            timestamp,
            nullifier,
            domain
        );
        bool success = this.verifyProof(pA, pB, pC, pubSignals);
        return (success, emailHash, dkimKeyHash, timestamp, domain);
    }

    /**
     * @notice Generates public signals for ZK proof verification
     * @dev Packs account data and proof details into the required format
     * @param _account Address of the account
     * @param _validator Address of the validator
     * @param _newPubKeyHash Hash of the new public key
     * @param _emailHash Email hash
     * @param _dkimKeyHash DKIM key hash
     * @param _timestamp Timestamp
     * @param _nullifier Nullifier
     * @param _domain Domain
     * @return publicSignals Array of public signals for ZK proof verification
     */
    function _genPubSignal(
        address _account,
        address _validator,
        bytes32 _newPubKeyHash,
        bytes32 _emailHash,
        bytes32 _dkimKeyHash,
        uint256 _timestamp,
        bytes32 _nullifier,
        string memory _domain
    ) internal pure returns (uint256[17] memory publicSignals) {
        // Pack domain string into fields (first 9 slots)
        uint256[] memory domainFields = _packBytes2Fields(
            bytes(_domain),
            DOMAIN_BYTES
        );
        for (uint256 i = 0; i < DOMAIN_FIELDS; i++) {
            publicSignals[i] = domainFields[i];
        }

        // Pack core verification data (slots 9-12)
        publicSignals[DOMAIN_FIELDS] = uint256(_dkimKeyHash);
        publicSignals[DOMAIN_FIELDS + 1] = uint256(_nullifier);
        publicSignals[DOMAIN_FIELDS + 2] = uint256(_emailHash);

        // Pack addresses and public key (slots 13-16)
        publicSignals[DOMAIN_FIELDS + 3] = _packBytes2Fields(
            abi.encodePacked(_account),
            20
        )[0];
        publicSignals[DOMAIN_FIELDS + 4] = _packBytes2Fields(
            abi.encodePacked(_validator),
            20
        )[0];

        // Split and pack public key hash
        (bytes16 pubKeyHigh, bytes16 pubKeyLow) = split32To16(_newPubKeyHash);
        publicSignals[DOMAIN_FIELDS + 5] = _packBytes2Fields(
            abi.encodePacked(pubKeyHigh),
            16
        )[0];
        publicSignals[DOMAIN_FIELDS + 6] = _packBytes2Fields(
            abi.encodePacked(pubKeyLow),
            16
        )[0];

        // Pack timestamp (slot 17)
        publicSignals[DOMAIN_FIELDS + 7] = _timestamp;
    }

    /**
     * @notice Splits a bytes32 value into two bytes16 values
     * @param _data The bytes32 value to split
     * @return high The high bytes16 value
     * @return low The low bytes16 value
     */
    function split32To16(bytes32 _data) public pure returns (bytes16, bytes16) {
        bytes16 high = bytes16(_data);
        bytes16 low = bytes16(uint128(uint256(_data)));
        return (high, low);
    }

    /**
     * @notice Packs bytes into fields for ZK proof
     * @dev Converts byte array into fixed-size fields for proof verification
     * @param _bytes Bytes to pack
     * @param _paddedSize Desired size after padding
     * @return uint256[] Array of packed fields
     */
    function _packBytes2Fields(
        bytes memory _bytes,
        uint256 _paddedSize
    ) internal pure returns (uint256[] memory) {
        uint256 numFields = (_paddedSize + 30) / 31;
        uint256[] memory fields = new uint256[](numFields);

        unchecked {
            uint256 idx = 0;
            for (uint256 i = 0; i < numFields; ++i) {
                uint256 field = 0;

                for (
                    uint256 j = 0;
                    j < 248 && idx < _paddedSize;
                    (j += 8, ++idx)
                )
                    if (idx < _bytes.length)
                        field |= uint256(uint8(_bytes[idx])) << j;

                fields[i] = field;
            }
        }

        return fields;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
