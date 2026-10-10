// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

library DynamicClusterInputLib {
    string internal constant SCHEMA = "evk-market-ops-cluster-input-v1";

    struct Input {
        string schema;
        string requestHash;
        string sourceCommit;
        uint256 chainId;
        uint256 blockNumber;
        bytes32 blockHash;
        address deployer;
        address oracleRoutersGovernor;
        address vaultsGovernor;
        address[] assets;
        address[] vaults;
        address[] oracleRouters;
        address[] irms;
        address[] externalVaults;
        address stubOracle;
        bool noStubOracle;
        address unitOfAccount;
        address feeReceiver;
        uint16 interestFee;
        uint16 maxLiquidationDiscount;
        uint16 liquidationCoolOffTime;
        address hookTarget;
        uint32 hookedOps;
        uint32 configFlags;
        bool forceZeroGovernors;
        uint32 rampDuration;
        uint16 spreadLTV;
        address[] oracleProviderBases;
        string[] oracleProviders;
        uint256[] supplyCaps;
        uint256[] borrowCaps;
        address[] feeReceiverOverrides;
        uint16[] interestFeeOverrides;
        uint16[] maxLiquidationDiscountOverrides;
        uint16[] liquidationCoolOffTimeOverrides;
        address[] hookTargetOverrides;
        uint32[] hookedOpsOverrides;
        uint32[] configFlagsOverrides;
        uint256[4][] kinkIRMParams;
        uint16[][] ltvs;
        uint16[][] borrowLTVsOverride;
        uint16[][] spreadLTVOverride;
        uint16[][] externalLTVs;
        uint16[][] externalBorrowLTVsOverride;
        uint16[][] externalSpreadLTVsOverride;
    }

    function read(Vm vm, string memory path) internal view returns (Input memory input, bytes32 inputHash) {
        string memory json = vm.readFile(path);
        inputHash = keccak256(bytes(json));

        input.schema = vm.parseJsonString(json, ".schema");
        require(keccak256(bytes(input.schema)) == keccak256(bytes(SCHEMA)), "DynamicClusterInput: schema");

        input.requestHash = vm.parseJsonString(json, ".requestHash");
        input.sourceCommit = vm.parseJsonString(json, ".sourceCommit");
        input.chainId = _readUint(vm, json, ".chainId");
        input.blockNumber = _readUint(vm, json, ".blockNumber");
        input.blockHash = vm.parseJsonBytes32(json, ".blockHash");
        input.deployer = vm.parseJsonAddress(json, ".deployer");
        input.oracleRoutersGovernor = vm.parseJsonAddress(json, ".oracleRoutersGovernor");
        input.vaultsGovernor = vm.parseJsonAddress(json, ".vaultsGovernor");
        input.assets = vm.parseJsonAddressArray(json, ".assets");
        input.vaults = vm.parseJsonAddressArray(json, ".vaults");
        input.oracleRouters = vm.parseJsonAddressArray(json, ".oracleRouters");
        input.irms = vm.parseJsonAddressArray(json, ".irms");
        input.externalVaults = vm.parseJsonAddressArray(json, ".externalVaults");
        input.stubOracle = vm.parseJsonAddress(json, ".stubOracle");
        input.noStubOracle = vm.parseJsonBool(json, ".noStubOracle");
        input.unitOfAccount = vm.parseJsonAddress(json, ".unitOfAccount");
        input.feeReceiver = vm.parseJsonAddress(json, ".feeReceiver");
        input.interestFee = _readUint16(vm, json, ".interestFee");
        input.maxLiquidationDiscount = _readUint16(vm, json, ".maxLiquidationDiscount");
        input.liquidationCoolOffTime = _readUint16(vm, json, ".liquidationCoolOffTime");
        input.hookTarget = vm.parseJsonAddress(json, ".hookTarget");
        input.hookedOps = _readUint32(vm, json, ".hookedOps");
        input.configFlags = _readUint32(vm, json, ".configFlags");
        input.forceZeroGovernors = vm.parseJsonBool(json, ".forceZeroGovernors");
        input.rampDuration = _readUint32(vm, json, ".rampDuration");
        input.spreadLTV = _readUint16(vm, json, ".spreadLTV");
        input.oracleProviderBases = vm.parseJsonAddressArray(json, ".oracleProviderBases");
        input.oracleProviders = vm.parseJsonStringArray(json, ".oracleProviders");
        input.supplyCaps = _readUintArray(vm, json, ".supplyCaps");
        input.borrowCaps = _readUintArray(vm, json, ".borrowCaps");
        input.feeReceiverOverrides = vm.parseJsonAddressArray(json, ".feeReceiverOverrides");
        input.interestFeeOverrides = _readUint16Array(vm, json, ".interestFeeOverrides");
        input.maxLiquidationDiscountOverrides =
            _readUint16Array(vm, json, ".maxLiquidationDiscountOverrides");
        input.liquidationCoolOffTimeOverrides =
            _readUint16Array(vm, json, ".liquidationCoolOffTimeOverrides");
        input.hookTargetOverrides = vm.parseJsonAddressArray(json, ".hookTargetOverrides");
        input.hookedOpsOverrides = _readUint32Array(vm, json, ".hookedOpsOverrides");
        input.configFlagsOverrides = _readUint32Array(vm, json, ".configFlagsOverrides");

        uint256 assetCount = input.assets.length;
        input.kinkIRMParams = _readUint256x4Array(vm, json, ".kinkIRMParams", assetCount);
        input.ltvs = _readUint16Matrix(vm, json, ".ltvs", assetCount, assetCount);
        input.borrowLTVsOverride =
            _readUint16Matrix(vm, json, ".borrowLTVsOverride", assetCount, assetCount);
        input.spreadLTVOverride =
            _readUint16Matrix(vm, json, ".spreadLTVOverride", assetCount, assetCount);
        input.externalLTVs =
            _readUint16Matrix(vm, json, ".externalLTVs", input.externalVaults.length, assetCount);
        input.externalBorrowLTVsOverride = _readUint16Matrix(
            vm, json, ".externalBorrowLTVsOverride", input.externalVaults.length, assetCount
        );
        input.externalSpreadLTVsOverride = _readUint16Matrix(
            vm, json, ".externalSpreadLTVsOverride", input.externalVaults.length, assetCount
        );

        _validate(input);
    }

    function _validate(Input memory input) private pure {
        uint256 assetCount = input.assets.length;
        require(_isSha256Hash(input.requestHash), "DynamicClusterInput: request hash");
        require(_isLowerHexCommit(input.sourceCommit), "DynamicClusterInput: source commit");
        require(input.chainId != 0, "DynamicClusterInput: chain");
        require(input.blockNumber != 0 && input.blockHash != bytes32(0), "DynamicClusterInput: block");
        require(input.deployer != address(0), "DynamicClusterInput: deployer");
        require(assetCount != 0, "DynamicClusterInput: assets");
        _requireUniqueNonZero(input.assets, false, "DynamicClusterInput: duplicate asset");
        require(input.vaults.length == assetCount, "DynamicClusterInput: vaults");
        _requireUniqueNonZero(input.vaults, true, "DynamicClusterInput: duplicate vault");
        require(input.oracleRouters.length == assetCount, "DynamicClusterInput: routers");
        require(input.irms.length == assetCount, "DynamicClusterInput: irms");
        _requireUniqueNonZero(input.externalVaults, false, "DynamicClusterInput: duplicate external vault");
        for (uint256 i = 0; i < input.externalVaults.length; ++i) {
            for (uint256 j = 0; j < input.vaults.length; ++j) {
                require(input.externalVaults[i] != input.vaults[j], "DynamicClusterInput: overlapping vault");
            }
        }
        require(input.unitOfAccount != address(0), "DynamicClusterInput: unit of account");
        require(
            input.forceZeroGovernors
                || (input.oracleRoutersGovernor != address(0) && input.vaultsGovernor != address(0)),
            "DynamicClusterInput: governors"
        );
        require(
            input.oracleProviderBases.length == input.oracleProviders.length,
            "DynamicClusterInput: oracle providers"
        );
        _requireUniqueNonZero(input.oracleProviderBases, false, "DynamicClusterInput: duplicate oracle base");
        for (uint256 i = 0; i < input.oracleProviders.length; ++i) {
            require(bytes(input.oracleProviders[i]).length != 0, "DynamicClusterInput: empty oracle provider");
        }
        require(input.supplyCaps.length == assetCount, "DynamicClusterInput: supply caps");
        require(input.borrowCaps.length == assetCount, "DynamicClusterInput: borrow caps");
        require(input.feeReceiverOverrides.length == assetCount, "DynamicClusterInput: fee overrides");
        require(input.interestFeeOverrides.length == assetCount, "DynamicClusterInput: interest fee overrides");
        require(
            input.maxLiquidationDiscountOverrides.length == assetCount,
            "DynamicClusterInput: liquidation discount overrides"
        );
        require(
            input.liquidationCoolOffTimeOverrides.length == assetCount,
            "DynamicClusterInput: cool off overrides"
        );
        require(input.hookTargetOverrides.length == assetCount, "DynamicClusterInput: hook overrides");
        require(input.hookedOpsOverrides.length == assetCount, "DynamicClusterInput: hooked ops overrides");
        require(input.configFlagsOverrides.length == assetCount, "DynamicClusterInput: config flag overrides");
    }

    function _isLowerHexCommit(string memory value) private pure returns (bool) {
        bytes memory encoded = bytes(value);
        if (encoded.length != 40) return false;
        for (uint256 i = 0; i < encoded.length; ++i) {
            bytes1 character = encoded[i];
            if (!((character >= "0" && character <= "9") || (character >= "a" && character <= "f"))) return false;
        }
        return true;
    }

    function _isSha256Hash(string memory value) private pure returns (bool) {
        bytes memory encoded = bytes(value);
        bytes memory prefix = bytes("sha256:");
        if (encoded.length != prefix.length + 64) return false;
        for (uint256 i = 0; i < prefix.length; ++i) {
            if (encoded[i] != prefix[i]) return false;
        }
        for (uint256 i = prefix.length; i < encoded.length; ++i) {
            bytes1 character = encoded[i];
            if (!((character >= "0" && character <= "9") || (character >= "a" && character <= "f"))) return false;
        }
        return true;
    }

    function _requireUniqueNonZero(address[] memory values, bool allowZero, string memory error) private pure {
        for (uint256 i = 0; i < values.length; ++i) {
            require(allowZero || values[i] != address(0), error);
            if (values[i] == address(0)) continue;
            for (uint256 j = i + 1; j < values.length; ++j) {
                require(values[i] != values[j], error);
            }
        }
    }

    function _readUint(Vm vm, string memory json, string memory key) private pure returns (uint256) {
        return vm.parseUint(vm.parseJsonString(json, key));
    }

    function _readUint16(Vm vm, string memory json, string memory key) private pure returns (uint16 result) {
        uint256 value = _readUint(vm, json, key);
        require(value <= type(uint16).max, "DynamicClusterInput: uint16 overflow");
        result = uint16(value);
    }

    function _readUint32(Vm vm, string memory json, string memory key) private pure returns (uint32 result) {
        uint256 value = _readUint(vm, json, key);
        require(value <= type(uint32).max, "DynamicClusterInput: uint32 overflow");
        result = uint32(value);
    }

    function _readUintArray(Vm vm, string memory json, string memory key)
        private
        pure
        returns (uint256[] memory values)
    {
        string[] memory encoded = vm.parseJsonStringArray(json, key);
        values = new uint256[](encoded.length);
        for (uint256 i = 0; i < encoded.length; ++i) values[i] = vm.parseUint(encoded[i]);
    }

    function _readUint16Array(Vm vm, string memory json, string memory key)
        private
        pure
        returns (uint16[] memory values)
    {
        uint256[] memory wide = _readUintArray(vm, json, key);
        values = new uint16[](wide.length);
        for (uint256 i = 0; i < wide.length; ++i) {
            require(wide[i] <= type(uint16).max, "DynamicClusterInput: uint16 array overflow");
            values[i] = uint16(wide[i]);
        }
    }

    function _readUint32Array(Vm vm, string memory json, string memory key)
        private
        pure
        returns (uint32[] memory values)
    {
        uint256[] memory wide = _readUintArray(vm, json, key);
        values = new uint32[](wide.length);
        for (uint256 i = 0; i < wide.length; ++i) {
            require(wide[i] <= type(uint32).max, "DynamicClusterInput: uint32 array overflow");
            values[i] = uint32(wide[i]);
        }
    }

    function _readUint256x4Array(Vm vm, string memory json, string memory key, uint256 rows)
        private
        pure
        returns (uint256[4][] memory values)
    {
        values = new uint256[4][](rows);
        for (uint256 i = 0; i < rows; ++i) {
            uint256[] memory row = _readUintArray(vm, json, string.concat(key, "[", vm.toString(i), "]"));
            require(row.length == 4, "DynamicClusterInput: IRM row");
            values[i] = [row[0], row[1], row[2], row[3]];
        }
    }

    function _readUint16Matrix(
        Vm vm,
        string memory json,
        string memory key,
        uint256 rows,
        uint256 columns
    ) private pure returns (uint16[][] memory values) {
        values = new uint16[][](rows);
        for (uint256 i = 0; i < rows; ++i) {
            values[i] = _readUint16Array(vm, json, string.concat(key, "[", vm.toString(i), "]"));
            require(values[i].length == columns, "DynamicClusterInput: matrix row");
        }
    }
}
