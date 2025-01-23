// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {stdJson} from "forge-std/StdJson.sol";
import {ScriptExtended} from "./ScriptExtended.s.sol";

contract LayerZeroUtil is ScriptExtended {
    using stdJson for string;

    struct DeploymentInfo {
        uint32 eid;
        string chainKey;
        address endpointV2;
        address executor;
        address sendUln302;
        address receiveUln302;
    }

    function getRawMetadata() public returns (string memory) {
        string[] memory inputs = new string[](3);
        inputs[0] = "curl";
        inputs[1] = "-s";
        inputs[2] = getMatadataAPIURL();
        bytes memory result = vm.ffi(inputs);

        require(result.length != 0, "getRawMetadata: failed to get metadata");

        return string(result);
    }

    function getDeploymentInfo(uint256 chainId) public returns (DeploymentInfo memory) {
        return getDeploymentInfo(getRawMetadata(), chainId);
    }

    function getDeploymentInfo(string memory metadata, uint256 chainId)
        public
        view
        returns (DeploymentInfo memory result)
    {
        string[] memory keys = vm.parseJsonKeys(metadata, ".");

        for (uint256 i = 0; i < keys.length; ++i) {
            string memory key = string.concat(".", keys[i]);

            if (
                metadata.readUintOr(string.concat(key, ".chainDetails.nativeChainId"), 0) != chainId
                    || !vm.keyExists(metadata, string.concat(key, ".deployments"))
            ) continue;

            uint256 deploymentsLength =
                abi.decode(vm.parseJson(metadata, string.concat(key, ".deployments")), (string[])).length;

            for (uint256 j = 0; j < deploymentsLength; ++j) {
                if (!vm.keyExists(metadata, string.concat(key, ".deployments[", vm.toString(j), "].endpointV2"))) {
                    continue;
                }

                result = DeploymentInfo({
                    eid: uint32(
                        vm.parseUint(
                            metadata.readStringOr(string.concat(key, ".deployments[", vm.toString(j), "].eid"), "0")
                        )
                    ),
                    chainKey: metadata.readStringOr(string.concat(key, ".deployments[", vm.toString(j), "].chainKey"), ""),
                    endpointV2: metadata.readAddressOr(
                        string.concat(key, ".deployments[", vm.toString(j), "].endpointV2.address"), address(0)
                    ),
                    executor: metadata.readAddressOr(
                        string.concat(key, ".deployments[", vm.toString(j), "].executor.address"), address(0)
                    ),
                    sendUln302: metadata.readAddressOr(
                        string.concat(key, ".deployments[", vm.toString(j), "].sendUln302.address"), address(0)
                    ),
                    receiveUln302: metadata.readAddressOr(
                        string.concat(key, ".deployments[", vm.toString(j), "].receiveUln302.address"), address(0)
                    )
                });

                break;
            }

            if (
                result.endpointV2 != address(0) && result.executor != address(0) && result.sendUln302 != address(0)
                    && result.receiveUln302 != address(0)
            ) {
                break;
            }
        }

        require(
            result.endpointV2 == address(0)
                || (result.executor != address(0) && result.sendUln302 != address(0) && result.receiveUln302 != address(0)),
            "getDeploymentInfo: executor, sendUln302, or receiveUln302 is not set"
        );
    }

    function getDVNAddresses(string[] memory dvns, string memory chainKey)
        public
        returns (string[] memory, address[] memory)
    {
        return getDVNAddresses(getRawMetadata(), dvns, chainKey);
    }

    function getDVNAddresses(string memory metadata, string[] memory dvns, string memory chainKey)
        public
        view
        returns (string[] memory dvnNames, address[] memory dvnAddresses)
    {
        string memory key = string.concat(".", chainKey, ".dvns");
        require(vm.keyExists(metadata, key), "getDVNAddresses: dvns not found for a given chainKey");

        string[] memory keys = vm.parseJsonKeys(metadata, key);
        dvnNames = new string[](dvns.length);
        dvnAddresses = new address[](dvns.length);
        uint256 index;

        for (uint256 i = 0; i < dvns.length; ++i) {
            for (uint256 j = 0; j < keys.length; ++j) {
                if (
                    _strEq(metadata.readStringOr(string.concat(key, ".", keys[j], ".canonicalName"), ""), dvns[i])
                        && metadata.readBoolOr(string.concat(key, ".", keys[j], ".lzReadCompatible"), true)
                        && metadata.readBoolOr(string.concat(key, ".", keys[j], ".deprecated"), true)
                ) {
                    dvnNames[index] = dvns[i];
                    dvnAddresses[index++] = _toAddress(keys[j]);
                    break;
                }
            }
        }

        assembly {
            mstore(dvnNames, index)
            mstore(dvnAddresses, index)
        }
    }

    function getMatadataAPIURL() public pure returns (string memory) {
        return "https://metadata.layerzero-api.com/v1/metadata";
    }
}
