// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

abstract contract ScriptExtended is Script {
    uint256 internal constant DEFAULT_FORK_CHAIN_ID = 0;

    mapping(uint256 => uint256) private forks;
    address private deployerAddress;
    address private safeSignerAddress;

    constructor() {
        vm.pauseGasMetering();

        forks[DEFAULT_FORK_CHAIN_ID] = vm.activeFork();

        if (forks[DEFAULT_FORK_CHAIN_ID] == 0) {
            forks[DEFAULT_FORK_CHAIN_ID] = vm.createSelectFork(getDeploymentRpcUrl());
        }

        forks[block.chainid] = forks[DEFAULT_FORK_CHAIN_ID];

        uint256 deployerPK = vm.envOr("DEPLOYER_KEY", uint256(0));
        uint256 safeSignerPK = vm.envOr("SAFE_KEY", uint256(0));
        uint256 rememberDeployerLength;
        uint256 rememberSafeSignerLength;

        if (deployerPK != 0) {
            vm.rememberKey(deployerPK);
            rememberDeployerLength = vm.getWallets().length;
        }

        if (safeSignerPK != 0) {
            vm.rememberKey(safeSignerPK);
            rememberSafeSignerLength = vm.getWallets().length;
        }

        address[] memory wallets = vm.getWallets();
        if (wallets.length > 0) {
            deployerAddress = rememberDeployerLength > 0 ? wallets[rememberDeployerLength - 1] : wallets[0];
            safeSignerAddress = rememberSafeSignerLength > 0
                ? wallets[rememberSafeSignerLength - 1]
                : rememberDeployerLength > 0 ? wallets[0] : wallets.length > 1 ? wallets[1] : wallets[0];
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
        string memory safeAddress = vm.envOr("SAFE_ADDRESS", string(""));
        address safe;

        if (_strEq(safeAddress, string(""))) {
            safeAddress = vm.envOr("safe_address", string(""));

            if (bytes(safeAddress).length > 0) {
                safe = getAddressFromJson(getAddressesJson("MultisigAddresses.json"), string.concat(".", safeAddress));
            }
        }

        if (safe == address(0)) safe = _toAddress(safeAddress);

        require(safe != address(0), "getSafe: Cannot retrieve the Safe address");
        return safe;
    }

    function getSafeNonce() internal view returns (uint256) {
        uint256 nonce = vm.envOr("SAFE_NONCE", uint256(0));

        if (nonce == 0) {
            nonce = vm.envOr("safe_nonce", uint256(0));
        }

        return nonce;
    }

    function getDeploymentRpcUrl() internal view returns (string memory) {
        return vm.envString("DEPLOYMENT_RPC_URL");
    }

    function getRpcUrl(uint256 chainId, bool failOnNotFound) internal view returns (string memory) {
        if (failOnNotFound) {
            return vm.envString(string.concat("DEPLOYMENT_RPC_URL_", vm.toString(chainId)));
        } else {
            return vm.envOr(string.concat("DEPLOYMENT_RPC_URL_", vm.toString(chainId)), string(""));
        }
    }

    function getLocalRpcUrl() internal pure returns (string memory) {
        return "http://127.0.0.1:8545";
    }

    function isLocalForkDeployment() internal view returns (bool) {
        return _strEq(getDeploymentRpcUrl(), getLocalRpcUrl());
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

    function getAddressesDirPath() internal view returns (string memory) {
        string memory path = vm.envOr("ADDRESSES_DIR_PATH", string(""));
        path =
            bytes(path).length == 0 ? "" : bytes(path)[bytes(path).length - 1] == "/" ? path : string.concat(path, "/");

        require(
            vm.isDir(path),
            "getAddressesDirPath: ADDRESSES_DIR_PATH environment variable is not set or the directory does not exist"
        );
        return path;
    }

    function getAddressFromJson(string memory json, string memory key) internal pure returns (address) {
        try vm.parseJson(json, key) returns (bytes memory data) {
            if (data.length < 32) return address(0);
            else return abi.decode(data, (address));
        } catch {
            return address(0);
        }
    }

    function getAddressesFromJson(string memory json, string memory key) internal pure returns (address[] memory) {
        try vm.parseJson(json, key) returns (bytes memory data) {
            if (data.length < 32) return new address[](0);
            else return abi.decode(data, (address[]));
        } catch {
            return new address[](0);
        }
    }

    function getScriptFilePath(string memory jsonFile) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/script/", jsonFile);
    }

    function getScriptFile(string memory jsonFile) internal view returns (string memory) {
        return vm.readFile(getScriptFilePath(jsonFile));
    }

    function getAddressesFilePath(string memory jsonFile, uint256 chainId) internal view returns (string memory) {
        return string.concat(getAddressesDirPath(), vm.toString(chainId), "/", jsonFile);
    }

    function getAddressesJson(string memory jsonFile, uint256 chainId) internal view returns (string memory) {
        try vm.readFile(getAddressesFilePath(jsonFile, chainId)) returns (string memory result) {
            return result;
        } catch {
            return "";
        }
    }

    function getAddressesJson(string memory jsonFile) internal view returns (string memory) {
        return getAddressesJson(jsonFile, block.chainid);
    }

    function getChainIdFromAddressessDirPath(string memory path) internal pure returns (uint256) {
        bytes memory pathBytes = bytes(path);
        if (pathBytes.length == 0) return 0;

        // Remove trailing slash if present
        uint256 endIndex = pathBytes[pathBytes.length - 1] == "/" ? pathBytes.length - 1 : pathBytes.length;

        // Find the last slash
        uint256 lastSlashIndex;
        for (uint256 i = 0; i < endIndex; ++i) {
            if (pathBytes[i] == "/") {
                lastSlashIndex = i + 1;
            }
        }

        // Extract the last directory name
        string memory lastDir = _substring(path, lastSlashIndex, endIndex);

        // Try to convert to number
        uint256 chainId;
        try vm.parseUint(lastDir) returns (uint256 parsed) {
            chainId = parsed;
        } catch {
            chainId = 0;
        }

        return chainId;
    }

    function getBridgeConfigCacheJsonFilePath(string memory jsonFile) internal view returns (string memory) {
        return string.concat(getAddressesDirPath(), "../config/bridge/", jsonFile);
    }

    function getBridgeConfigCacheJson(string memory jsonFile) internal view returns (string memory) {
        try vm.readFile(getBridgeConfigCacheJsonFilePath(jsonFile)) returns (string memory result) {
            return result;
        } catch {
            return "";
        }
    }

    function selectFork(uint256 chainId) internal returns (bool) {
        require(forks[0] != 0, "selectFork: default fork not found");

        if (forks[chainId] == 0) {
            string memory rpcUrl = getRpcUrl(chainId, false);

            if (bytes(rpcUrl).length == 0) return false;

            forks[chainId] = vm.createFork(rpcUrl);
        }

        vm.selectFork(forks[chainId]);
        return true;
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
        endIndex == type(uint256).max ? endIndex = strBytes.length : endIndex;

        if (startIndex >= strBytes.length || endIndex > strBytes.length || endIndex <= startIndex) return "";

        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; ++i) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function _toAddress(string memory _address) internal pure returns (address) {
        bytes memory tmp = bytes(_address);
        require(tmp.length == 42, "Invalid address length");

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

    function _indexedKey(string memory preIndex, uint256 index, string memory postIndex)
        internal
        pure
        returns (string memory)
    {
        return string.concat(preIndex, "[", vm.toString(index), "]", postIndex);
    }
}
