// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

interface IZkEmailVerifier {
    function initialize(address _owner) external;

    function verify(
        address _account,
        address _validator,
        bytes32 _newPubKeyHash,
        bytes calldata _proof
    )
        external
        view
        returns (
            bool success,
            bytes32 emailHash,
            bytes32 dkimKeyHash,
            uint256 timestamp,
            string memory domain
        );
}
