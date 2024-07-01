// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {ISecurityValidator} from "./ISecurityValidator.sol";

interface ISecurityPolicy {
    function saveAttestation(ISecurityValidator.Attestation calldata attestation, bytes calldata attestationSignature)
        external;
}
