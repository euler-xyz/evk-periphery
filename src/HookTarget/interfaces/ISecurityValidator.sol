// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

interface ISecurityValidator {
    /// @notice Set of values that enable execution of call(s)
    struct Attestation {
        /// @notice Creation UNIX timestamp
        uint256 timestamp;
        /**
         * @notice The amount of seconds until this attestation becomes invalid
         * Expiry is preferred over non-replayability due to expiry being a
         * sufficiently safe mechanism and not requiring persistent storage reads/writes.
         */
        uint256 timeout;
        /**
         * @notice Ordered hashes which should be produced at every checkpoint execution
         * in this contract. An attester uses these hashes to enable a specific execution
         * path.
         */
        bytes32[] executionHashes;
    }

    function getCurrentAttester() external view returns (address);
    function saveAttestation(Attestation calldata attestation, bytes calldata attestationSignature) external;
    function executeCheckpoint(bytes32 checkpointHash) external;
    function allCheckpointsExecuted() external view returns (bool);
}
