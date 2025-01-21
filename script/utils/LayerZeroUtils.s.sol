// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {stdJson} from "forge-std/StdJson.sol";
import {ScriptExtended} from "./ScriptExtended.s.sol";

abstract contract LayerZeroUtil is ScriptExtended {
    using stdJson for string;

    function getRawMetadata() public returns (string memory) {
        string[] memory inputs = new string[](3);
        inputs[0] = "curl";
        inputs[1] = "-s";
        inputs[2] = getMatadataAPIURL();
        bytes memory result = vm.ffi(inputs);

        require(result.length != 0, "getRawMetadata: failed to get metadata");

        return string(result);
    }

    function getDeploymentInfo(string memory eid) public returns (address, address, address, string memory) {
        return getDeploymentInfo(getRawMetadata(), eid);
    }

    function getDeploymentInfo(string memory metadata, string memory eid)
        public
        view
        returns (address executor, address sendUln302, address receiveUln302, string memory chainKey)
    {
        string[] memory keys = vm.parseJsonKeys(metadata, ".");

        for (uint256 i = 0; i < keys.length; ++i) {
            string memory key = string.concat(".", keys[i]);

            if (!vm.keyExists(metadata, string.concat(key, ".deployments"))) continue;

            uint256 deploymentsLength =
                abi.decode(vm.parseJson(metadata, string.concat(key, ".deployments")), (string[])).length;

            for (uint256 j = 0; j < deploymentsLength; ++j) {
                if (
                    !_strEq(metadata.readStringOr(string.concat(key, ".deployments[", vm.toString(j), "].eid"), ""), eid)
                ) continue;

                executor = metadata.readAddressOr(
                    string.concat(key, ".deployments[", vm.toString(j), "].executor.address"), address(0)
                );
                sendUln302 = metadata.readAddressOr(
                    string.concat(key, ".deployments[", vm.toString(j), "].sendUln302.address"), address(0)
                );
                receiveUln302 = metadata.readAddressOr(
                    string.concat(key, ".deployments[", vm.toString(j), "].receiveUln302.address"), address(0)
                );
                chainKey = metadata.readStringOr(string.concat(key, ".deployments[", vm.toString(j), "].chainKey"), "");

                break;
            }

            if (executor != address(0) && sendUln302 != address(0) && receiveUln302 != address(0)) break;
        }

        require(
            executor != address(0) && sendUln302 != address(0) && receiveUln302 != address(0),
            "getDeploymentInfo: executor, sendUln302, or receiveUln302 is not set"
        );
    }

    function getDVNAddresses(string[] memory dvns, string memory chainKey) public returns (address[] memory) {
        return getDVNAddresses(getRawMetadata(), dvns, chainKey);
    }

    function getDVNAddresses(string memory metadata, string[] memory dvns, string memory chainKey)
        public
        view
        returns (address[] memory dvnAddresses)
    {
        string memory key = string.concat(".", chainKey, ".dvns");
        require(vm.keyExists(metadata, key), "getDVNAddresses: dvns not found for a given chainKey");

        string[] memory keys = vm.parseJsonKeys(metadata, key);
        dvnAddresses = new address[](dvns.length);

        for (uint256 i = 0; i < dvns.length; ++i) {
            for (uint256 j = 0; j < keys.length; ++j) {
                if (
                    _strEq(metadata.readStringOr(string.concat(key, ".", keys[j], ".canonicalName"), ""), dvns[i])
                        && metadata.readBoolOr(string.concat(key, ".", keys[j], ".lzReadCompatible"), true)
                        && metadata.readBoolOr(string.concat(key, ".", keys[j], ".deprecated"), true)
                ) {
                    dvnAddresses[i] = _toAddress(keys[j]);
                    break;
                }

                require(j != keys.length - 1, "getDVNAddresses: dvn address not found for a given canonicalName");
            }
        }

        for (uint256 i = 0; i < dvnAddresses.length; ++i) {
            require(dvnAddresses[i] != address(0), "getDVNAddresses: not all dvn addresses found");
        }
    }

    function getMatadataAPIURL() public pure returns (string memory) {
        return "https://metadata.layerzero-api.com/v1/metadata";
    }
}

contract LZ is LayerZeroUtil {
    function run() public returns (address executor, address sendUln302, address receiveUln302, string memory) {
        return getDeploymentInfo("40247");
    }
}
