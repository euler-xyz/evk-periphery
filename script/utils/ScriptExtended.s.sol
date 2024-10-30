// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";

abstract contract ScriptExtended is Script {
    address private deployerAddress;
    address private safeSignerAddress;

    constructor() {
        uint256 deployerPK = vm.envOr("DEPLOYER_KEY", uint256(0));
        uint256 safeSignerPK = vm.envOr("SAFE_KEY", uint256(0));

        if (deployerPK != 0) {
            vm.rememberKey(deployerPK);
            deployerAddress = vm.addr(deployerPK);
        }

        if (safeSignerPK != 0) {
            vm.rememberKey(safeSignerPK);
            safeSignerAddress = vm.addr(safeSignerPK);
        }

        address[] memory wallets = vm.getWallets();
        if (deployerAddress == address(0) && wallets.length > 0) {
            deployerAddress = wallets[0];
        }

        if (safeSignerAddress == address(0) && wallets.length > 0) {
            safeSignerAddress = wallets.length > 1 ? wallets[1] : wallets[0];
        }

        if (!vm.envOr("FORCE_NO_KEY", false)) {
            require(deployerAddress != address(0), "Cannot retrieve the deployer address from the private key config");
            require(
                !isBatchViaSafe() || safeSignerAddress != address(0),
                "Cannot retrieve the safe signer address from the private key config"
            );
        }
    }

    function getDeployer() internal view returns (address) {
        return deployerAddress;
    }

    function getSafeSigner() internal view returns (address) {
        return safeSignerAddress;
    }

    function getSafe() internal view returns (address) {
        return vm.envAddress("SAFE_ADDRESS");
    }

    function getSafeCurrentNonce() internal view returns (uint256) {
        return vm.envOr("SAFE_NONCE", uint256(0));
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

    function isUseSafeApi() internal view returns (bool) {
        return _strEq(vm.envOr("use_safe_api", string("")), "--use-safe-api");
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

    function _stringToAddress(string memory _address) internal pure returns (address) {
        bytes memory tmp = bytes(_address);
        uint160 result = 0;
        uint160 b1;

        for (uint256 i = 2; i < tmp.length; ++i) {
            result *= 16;
            b1 = uint160(uint8(tmp[i]));

            if (b1 >= 48 && b1 <= 57) result += (b1 - 48);
            else if (b1 >= 65 && b1 <= 70) result += (b1 - 55);
            else if (b1 >= 97 && b1 <= 102) result += (b1 - 87);
            else revert("Invalid character in address string");
        }

        return address(result);
    }
}
