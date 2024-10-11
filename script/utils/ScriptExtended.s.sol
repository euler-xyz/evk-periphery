// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";

abstract contract ScriptExtended is Script {
    function getDeployerPK() internal view returns (uint256) {
        return vm.envUint("DEPLOYER_KEY");
    }

    function getSafePK() internal view returns (uint256) {
        return vm.envUint("SAFE_KEY");
    }

    function getSafePKOptional() internal view returns (uint256) {
        return vm.envOr("SAFE_KEY", uint256(0));
    }

    function getDeployer() internal view returns (address) {
        address deployer = vm.addr(vm.envOr("DEPLOYER_KEY", uint256(1)));
        return deployer == vm.addr(1) ? address(this) : deployer;
    }

    function getSafe() internal view returns (address) {
        return vm.envAddress("SAFE_ADDRESS");
    }

    function getSafeCurrentNonce() internal view returns (int256) {
        return vm.envOr("SAFE_NONCE", int256(-1));
    }

    function isLocalForkDeployment() internal view returns (bool) {
        return _strEq(vm.envString("DEPLOYMENT_RPC_URL"), "http://127.0.0.1:8545");
    }

    function isBroadcast() internal view returns (bool) {
        return _strEq(vm.envOr("broadcast", string("")), "--broadcast");
    }

    function isBatchViaSafe() internal view returns (bool) {
        return _strEq(vm.envOr("batch_via_safe", string("")), "--batch-via-safe");
    }

    function getAddressFromJson(string memory json, string memory key) internal pure returns (address) {
        try vm.parseJson(json, key) returns (bytes memory data) {
            return abi.decode(data, (address));
        } catch {
            revert(string.concat("getAddressFromJson: failed to parse JSON for key: ", key));
        }
    }

    function getAddressesFromJson(string memory json, string memory key) internal pure returns (address[] memory) {
        try vm.parseJson(json, key) returns (bytes memory data) {
            return abi.decode(data, (address[]));
        } catch {
            revert(string.concat("getAddressesFromJson: failed to parse JSON for key: ", key));
        }
    }

    function _strEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _substring(string memory str, uint256 startIndex, uint256 endIndex)
        internal
        pure
        returns (string memory)
    {
        bytes memory strBytes = bytes(str);

        if (startIndex >= strBytes.length || endIndex > strBytes.length || endIndex <= startIndex) return "";

        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; ++i) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
}
