// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, console} from "./ScriptUtils.s.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IPriceOracle} from "euler-price-oracle/interfaces/IPriceOracle.sol";
import {IPyth, PythStructs} from "euler-price-oracle/adapter/pyth/PythOracle.sol";
import {OracleLens, IOracle} from "../../src/Lens/OracleLens.sol";

contract SimulateSafeTxTenderly is ScriptUtils {
    mapping(address router => mapping(address base => mapping(address quote => bool checked))) internal oracleChecked;

    function run() public {
        string memory json = vm.readFile(vm.envString("CLUSTER_ADDRESSES_PATH"));
        address[] memory vaults = getAddressesFromJson(json, ".vaults");

        overrideLTVTargetTimestamps(vaults);
        overridePullOraclesTimestamps(vaults);
    }

    function overrideLTVTargetTimestamps(address[] memory vaults) public {
        for (uint256 i = 0; i < vaults.length; ++i) {
            address vault = vaults[i];
            address[] memory collaterals = IEVault(vault).LTVList();

            for (uint256 j = 0; j < collaterals.length; ++j) {
                (
                    uint16 borrowLTV,
                    uint16 liquidationLTV,
                    uint16 initialLiquidationLTV,
                    uint48 targetTimestamp,
                    uint32 rampDuration
                ) = IEVault(vault).LTVFull(collaterals[j]);

                if (targetTimestamp <= block.timestamp) continue;

                // we are setting the storage in a way that the LTV ramp down is considered complete
                tenderlySetStorageAt(
                    vault,
                    keccak256(abi.encode(uint256(uint160(collaterals[j])), uint256(14))),
                    bytes32(
                        abi.encodePacked(
                            uint128(0),
                            rampDuration,
                            uint48(block.timestamp),
                            initialLiquidationLTV,
                            liquidationLTV,
                            borrowLTV
                        )
                    )
                );
            }
        }
    }

    function overridePullOraclesTimestamps(address[] memory vaults) public {
        for (uint256 i = 0; i < vaults.length; ++i) {
            address vault = vaults[i];
            address oracle = IEVault(vault).oracle();
            address unitOfAccount = IEVault(vault).unitOfAccount();
            address[] memory collaterals = IEVault(vault).LTVList();

            for (uint256 j = 0; j <= collaterals.length; ++j) {
                address base = j == collaterals.length ? IEVault(vault).asset() : collaterals[j];

                if (oracleChecked[oracle][base][unitOfAccount]) continue;

                oracleChecked[oracle][base][unitOfAccount] = true;

                (, address finalBase,, address finalOracle) = IOracle(oracle).resolveOracle(0, base, unitOfAccount);

                (bool success, bytes memory result) =
                    oracle.staticcall(abi.encodeCall(IPriceOracle.getQuote, (0, finalBase, unitOfAccount)));

                if (success || !OracleLens(lensAddresses.oracleLens).isStalePullOracle(finalOracle, result)) continue;

                processOracle(finalOracle);
            }
        }
    }

    function processOracle(address oracle) internal {
        (bool success, bytes memory result) = oracle.staticcall(abi.encodeCall(IPriceOracle.name, ()));

        if (!success || result.length < 32) return;

        string memory name = abi.decode(result, (string));

        if (_strEq(name, "PythOracle")) {
            overridePythOracleTimestamp(oracle);
        } else if (_strEq(name, "RedstoneCoreOracle")) {
            overrideRedstoneOracleTimestamp(oracle);
        } else if (_strEq(name, "CrossAdapter")) {
            processOracle(IOracle(oracle).oracleBaseCross());
            processOracle(IOracle(oracle).oracleCrossQuote());
        }
    }

    function overridePythOracleTimestamp(address oracle) internal {
        address pyth = IOracle(oracle).pyth();
        bytes32 feedId = IOracle(oracle).feedId();
        PythStructs.Price memory p = IPyth(pyth).getPriceUnsafe(feedId);

        tenderlySetStorageAt(
            pyth,
            keccak256(abi.encode(feedId, uint256(213))),
            bytes32(abi.encodePacked(uint32(0), p.conf, p.price, p.expo, uint64(block.timestamp)))
        );
    }

    function overrideRedstoneOracleTimestamp(address oracle) internal {
        (uint208 price,) = IOracle(oracle).cache();

        tenderlySetStorageAt(oracle, bytes32(0), bytes32(abi.encodePacked(uint48(block.timestamp), price)));
    }

    function tenderlySetStorageAt(address target, bytes32 slot, bytes32 value) internal {
        string[] memory inputs = new string[](7);
        inputs[0] = "cast";
        inputs[1] = "rpc";
        inputs[2] = "--rpc-url";
        inputs[3] = vm.envString("TENDERLY_RPC_URL");
        inputs[4] = "tenderly_setStorageAt";
        inputs[5] =
            string.concat('["', vm.toString(target), '", "', vm.toString(slot), '", "', vm.toString(value), '"]');
        inputs[6] = "--raw";
        vm.ffi(inputs);
    }
}
