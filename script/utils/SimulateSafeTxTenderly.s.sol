// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

contract ClusterDump is ScriptUtils {
    function run() public {
        string memory json = vm.readFile(vm.envString("CLUSTER_ADDRESSES_PATH"));
        address[] memory vaults = getAddressesFromJson(json, ".vaults");

        transformCluster(vaults);
    }

    function transformCluster(address[] memory vaults) public {
        // this is to execute the RPC method on Tenderly RPC node
        string[] memory setStorageInputs = new string[](7);
        setStorageInputs[0] = "cast";
        setStorageInputs[1] = "rpc";
        setStorageInputs[2] = "--rpc-url";
        setStorageInputs[3] = vm.envString("TENDERLY_RPC_URL");
        setStorageInputs[4] = "tenderly_setStorageAt";
        setStorageInputs[6] = "--raw";

        for (uint256 i = 0; i < vaults.length; ++i) {
            address[] memory collaterals = IEVault(vaults[i]).LTVList();

            for (uint256 j = 0; j < collaterals.length; ++j) {
                (
                    uint16 borrowLTV,
                    uint16 liquidationLTV,
                    uint16 initialLiquidationLTV,
                    uint48 targetTimestamp,
                    uint32 rampDuration
                ) = IEVault(vaults[i]).LTVFull(collaterals[j]);

                if (targetTimestamp <= block.timestamp) continue;

                // we are setting the storage in a way that the LTV ramp down is considered complete
                setStorageInputs[5] = string.concat(
                    '["',
                    vm.toString(vaults[i]),
                    '", "',
                    vm.toString(keccak256(abi.encode(uint256(uint160(collaterals[j])), uint256(14)))),
                    '", "',
                    vm.toString(
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
                    ),
                    '"]'
                );

                vm.ffi(setStorageInputs);
            }
        }
    }
}
