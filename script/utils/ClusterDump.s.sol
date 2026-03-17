// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, console} from "./ScriptUtils.s.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import {EulerRouter, IPriceOracle} from "euler-price-oracle/EulerRouter.sol";
import {Lenses} from "../08_Lenses.s.sol";
import {IRMAdaptiveCurve} from "../../src/IRM/IRMAdaptiveCurve.sol";
import {IRMLens} from "../../src/Lens/IRMLens.sol";
import {VaultLens} from "../../src/Lens/VaultLens.sol";
import "../../src/Lens/LensTypes.sol";

contract ClusterDump is ScriptUtils {
    function run() public {
        string memory json = vm.readFile(vm.envString("CLUSTER_ADDRESSES_PATH"));
        address[] memory vaults = getAddressesFromJson(json, ".vaults");
        address[] memory externalVaults = getAddressesFromJson(json, ".externalVaults");

        dumpCluster(vaults, externalVaults);
    }

    function dumpCluster(address[] memory vaults, address[] memory externalVaults) public {
        Lenses deployer = new Lenses();
        address[] memory lenses = deployer.execute(
            coreAddresses.eVaultFactory,
            peripheryAddresses.oracleAdapterRegistry,
            peripheryAddresses.kinkIRMFactory,
            peripheryAddresses.adaptiveCurveIRMFactory,
            peripheryAddresses.kinkyIRMFactory,
            peripheryAddresses.fixedCyclicalBinaryIRMFactory
        );
        address vaultLens = lenses[4];

        VaultInfoFull[] memory vaultInfo;

        {
            uint256 counter;
            for (uint256 i = 0; i < vaults.length; ++i) {
                if (vaults[i] == address(0)) continue;
                ++counter;
            }

            vaultInfo = new VaultInfoFull[](counter);
            counter = 0;

            for (uint256 i = 0; i < vaults.length; ++i) {
                if (vaults[i] == address(0)) continue;
                vaultInfo[counter] = VaultLens(vaultLens).getVaultInfoFull(vaults[i]);
                ++counter;
            }
        }

        string memory header = "Asset";
        for (uint256 i = 0; i < vaultInfo.length; ++i) {
            header = string.concat(header, ",", vaultInfo[i].assetSymbol);
        }

        string memory outputScriptFileName = "./script/Table 1a. Cluster Borrow LTVs.csv";
        vm.writeLine(
            outputScriptFileName,
            string.concat(
                "Table 1. Liquidation loan-to-value (LTV) parameters: collateral (row), debt (column):\nTable 1a. Cluster Borrow LTVs:"
            )
        );
        vm.writeLine(outputScriptFileName, header);

        string memory line;
        for (uint256 i = 0; i < vaultInfo.length; ++i) {
            line = vaultInfo[i].assetSymbol;

            for (uint256 j = 0; j < vaultInfo.length; ++j) {
                bool found = false;
                for (uint256 k = 0; k < vaultInfo[j].collateralLTVInfo.length; ++k) {
                    if (vaultInfo[j].collateralLTVInfo[k].collateral != vaultInfo[i].vault) continue;
                    line = string.concat(line, ",", formatConfig(uint256(vaultInfo[j].collateralLTVInfo[k].borrowLTV)));
                    found = true;
                    break;
                }
                if (!found) line = string.concat(line, ",", formatConfig(0));
            }
            vm.writeLine(outputScriptFileName, line);
            line = "";
        }

        outputScriptFileName = "./script/Table 1b. Cluster Target Liquidation LTVs.csv";
        vm.writeLine(
            outputScriptFileName,
            string.concat(
                "\nTable 1. Liquidation loan-to-value (LTV) parameters: collateral (row), debt (column):\nTable 1b. Cluster Target Liquidation LTVs):"
            )
        );
        vm.writeLine(outputScriptFileName, header);

        for (uint256 i = 0; i < vaultInfo.length; ++i) {
            line = vaultInfo[i].assetSymbol;

            for (uint256 j = 0; j < vaultInfo.length; ++j) {
                bool found = false;
                for (uint256 k = 0; k < vaultInfo[j].collateralLTVInfo.length; ++k) {
                    if (vaultInfo[j].collateralLTVInfo[k].collateral != vaultInfo[i].vault) continue;
                    line = string.concat(
                        line, ",", formatConfig(uint256(vaultInfo[j].collateralLTVInfo[k].liquidationLTV))
                    );
                    found = true;
                    break;
                }
                if (!found) line = string.concat(line, ",", formatConfig(0));
            }
            vm.writeLine(outputScriptFileName, line);
            line = "";
        }

        outputScriptFileName = "./script/Table 1c. External Vaults Borrow LTVs.csv";
        vm.writeLine(
            outputScriptFileName,
            string.concat(
                "\nTable 1. Liquidation loan-to-value (LTV) parameters: collateral (row), debt (column):\nTable 1c. External Vaults Borrow LTVs:"
            )
        );
        if (externalVaults.length > 0) {
            vm.writeLine(outputScriptFileName, header);

            for (uint256 i = 0; i < externalVaults.length; ++i) {
                line = IEVault(externalVaults[i]).symbol();

                for (uint256 j = 0; j < vaultInfo.length; ++j) {
                    bool found = false;
                    for (uint256 k = 0; k < vaultInfo[j].collateralLTVInfo.length; ++k) {
                        if (vaultInfo[j].collateralLTVInfo[k].collateral != externalVaults[i]) continue;
                        line =
                            string.concat(line, ",", formatConfig(uint256(vaultInfo[j].collateralLTVInfo[k].borrowLTV)));
                        found = true;
                        break;
                    }
                    if (!found) line = string.concat(line, ",", formatConfig(0));
                }
                vm.writeLine(outputScriptFileName, line);
                line = "";
            }
        } else {
            vm.writeLine(outputScriptFileName, string.concat("None"));
        }

        outputScriptFileName = "./script/Table 1d. External Vaults Target Liquidation LTVs.csv";
        vm.writeLine(
            outputScriptFileName,
            string.concat(
                "\nTable 1. Liquidation loan-to-value (LTV) parameters: collateral (row), debt (column):\nTable 1d. External Vaults Target Liquidation LTVs:"
            )
        );
        if (externalVaults.length > 0) {
            vm.writeLine(outputScriptFileName, header);

            for (uint256 i = 0; i < externalVaults.length; ++i) {
                line = IEVault(externalVaults[i]).symbol();

                for (uint256 j = 0; j < vaultInfo.length; ++j) {
                    bool found = false;
                    for (uint256 k = 0; k < vaultInfo[j].collateralLTVInfo.length; ++k) {
                        if (vaultInfo[j].collateralLTVInfo[k].collateral != externalVaults[i]) continue;
                        line = string.concat(
                            line, ",", formatConfig(uint256(vaultInfo[j].collateralLTVInfo[k].liquidationLTV))
                        );
                        found = true;
                        break;
                    }
                    if (!found) line = string.concat(line, ",", formatConfig(0));
                }
                vm.writeLine(outputScriptFileName, line);
                line = "";
            }
        } else {
            vm.writeLine(outputScriptFileName, string.concat("None"));
        }

        outputScriptFileName = "./script/Table 1e. Cluster LTV Ramping.csv";
        vm.writeLine(
            outputScriptFileName,
            string.concat(
                "\nTable 1. Liquidation loan-to-value (LTV) parameters: collateral (row), debt (column):\nTable 1e. Cluster LTV Ramping:"
            )
        );

        vm.writeLine(outputScriptFileName, header);

        for (uint256 i = 0; i < vaultInfo.length; ++i) {
            line = vaultInfo[i].assetSymbol;

            for (uint256 j = 0; j < vaultInfo.length; ++j) {
                bool found = false;
                for (uint256 k = 0; k < vaultInfo[j].collateralLTVInfo.length; ++k) {
                    if (vaultInfo[j].collateralLTVInfo[k].collateral != vaultInfo[i].vault) continue;
                    line = string.concat(
                        line,
                        ",",
                        vm.toString(vaultInfo[j].collateralLTVInfo[k].targetTimestamp > block.timestamp ? 1 : 0)
                    );
                    found = true;
                    break;
                }
                if (!found) line = string.concat(line, ",", vm.toString(uint256(0)));
            }
            vm.writeLine(outputScriptFileName, line);
            line = "";
        }

        outputScriptFileName = "./script/Table 1f. External Vaults LTV Ramping.csv";
        vm.writeLine(
            outputScriptFileName,
            string.concat(
                "\nTable 1. Liquidation loan-to-value (LTV) parameters: collateral (row), debt (column):\nTable 1f. External Vaults LTV Ramping:"
            )
        );
        if (externalVaults.length > 0) {
            vm.writeLine(outputScriptFileName, header);

            for (uint256 i = 0; i < externalVaults.length; ++i) {
                line = IEVault(externalVaults[i]).symbol();

                for (uint256 j = 0; j < vaultInfo.length; ++j) {
                    bool found = false;
                    for (uint256 k = 0; k < vaultInfo[j].collateralLTVInfo.length; ++k) {
                        if (vaultInfo[j].collateralLTVInfo[k].collateral != externalVaults[i]) continue;
                        line = string.concat(
                            line,
                            ",",
                            vm.toString(vaultInfo[j].collateralLTVInfo[k].targetTimestamp > block.timestamp ? 1 : 0)
                        );
                        found = true;
                        break;
                    }
                    if (!found) line = string.concat(line, ",", vm.toString(uint256(0)));
                }
                vm.writeLine(outputScriptFileName, line);
                line = "";
            }
        } else {
            vm.writeLine(outputScriptFileName, string.concat("None"));
        }

        outputScriptFileName = "./script/Table 2. Supply & Borrow Caps.csv";
        header = "Asset,Supply Cap (unit),Borrow Cap (unit)";
        vm.writeLine(outputScriptFileName, string.concat("\nTable 2. Supply & Borrow Caps:"));
        vm.writeLine(outputScriptFileName, header);

        for (uint256 i = 0; i < vaultInfo.length; ++i) {
            line = vaultInfo[i].assetSymbol;
            line = string.concat(line, ",", formatAmount(vaultInfo[i].supplyCap, vaultInfo[i].assetDecimals));
            line = string.concat(line, ",", formatAmount(vaultInfo[i].borrowCap, vaultInfo[i].assetDecimals));
            vm.writeLine(outputScriptFileName, line);
            line = "";
        }

        outputScriptFileName = "./script/Table 3. Interest Rate Model Parameters.csv";
        header =
            "Asset,Class,Target utilisation,Reserve factor,Target Supply APR,Target Borrow APR,Max APR,Target Supply APY,Target Borrow APY,Max APY";
        vm.writeLine(outputScriptFileName, string.concat("\nTable 3. Interest Rate Model Parameters:"));
        vm.writeLine(outputScriptFileName, header);

        uint256[] memory cash = new uint256[](3);
        uint256[] memory borrows = new uint256[](3);
        cash[0] = type(uint32).max;
        borrows[2] = type(uint32).max;
        for (uint256 i = 0; i < vaultInfo.length; ++i) {
            InterestRateModelDetailedInfo memory detailedIRMInfo =
                IRMLens(lensAddresses.irmLens).getInterestRateModelInfo(IEVault(vaultInfo[i].vault).interestRateModel());

            if (detailedIRMInfo.interestRateModelType == InterestRateModelType.KINK) {
                uint256 kink = IRMLinearKink(detailedIRMInfo.interestRateModel).kink();
                cash[1] = type(uint32).max - kink;
                borrows[1] = kink;
            } else if (detailedIRMInfo.interestRateModelType == InterestRateModelType.ADAPTIVE_CURVE) {
                uint256 targetUtilization =
                    uint256(IRMAdaptiveCurve(detailedIRMInfo.interestRateModel).TARGET_UTILIZATION());
                cash[1] = (1e18 - targetUtilization) * type(uint32).max / 1e18;
                borrows[1] = targetUtilization * type(uint32).max / 1e18;
            }

            VaultInterestRateModelInfo memory irmInfo =
                VaultLens(vaultLens).getVaultInterestRateModelInfo(vaultInfo[i].vault, cash, borrows);

            line = string.concat(vaultInfo[i].assetSymbol);
            line = string.concat(
                line,
                ",",
                detailedIRMInfo.interestRateModelType == InterestRateModelType.KINK ? "Kink IRM" : "Adaptive Curve IRM"
            );
            line = string.concat(
                line,
                ",",
                irmInfo.interestRateInfo.length > 0
                    ? formatPercentage(irmInfo.interestRateInfo[1].borrows * 1e4 / type(uint32).max)
                    : ""
            );
            line = string.concat(line, ",", formatPercentage(vaultInfo[i].interestFee));
            line = string.concat(
                line,
                ",,,,",
                irmInfo.interestRateInfo.length > 0
                    ? formatPercentage(irmInfo.interestRateInfo[1].supplyAPY * 1e4 / 1e27)
                    : ""
            );
            line = string.concat(
                line,
                ",",
                irmInfo.interestRateInfo.length > 0
                    ? formatPercentage(irmInfo.interestRateInfo[1].borrowAPY * 1e4 / 1e27)
                    : ""
            );
            line = string.concat(
                line,
                ",",
                irmInfo.interestRateInfo.length > 0
                    ? formatPercentage(irmInfo.interestRateInfo[2].borrowAPY * 1e4 / 1e27)
                    : ""
            );
            vm.writeLine(outputScriptFileName, line);
            line = "";
        }

        outputScriptFileName = "./script/Table 4. Oracle Information.csv";
        header = "Asset,Quote,Adapter,Name,Methodology,Link";
        vm.writeLine(outputScriptFileName, string.concat("\nTable 4. Oracle Information:"));
        vm.writeLine(outputScriptFileName, header);

        for (uint256 i = 0; i < vaultInfo.length; ++i) {
            (,,, address adapter) =
                EulerRouter(vaultInfo[i].oracle).resolveOracle(0, vaultInfo[i].vault, vaultInfo[i].unitOfAccount);
            line = vaultInfo[i].assetSymbol;
            line = string.concat(
                line,
                ",",
                vaultInfo[i].unitOfAccount == address(840)
                    ? "USD"
                    : vaultInfo[i].unitOfAccount == address(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB)
                        ? "BTC"
                        : vaultInfo[i].unitOfAccountSymbol
            );
            line = string.concat(line, ",", vm.toString(adapter));
            if (adapter == address(0)) {
                line = string.concat(line, ",,,");
            } else {
                line = string.concat(line, ",", IPriceOracle(adapter).name());
                line = string.concat(
                    line,
                    ",,https://oracles.euler.finance/",
                    vm.toString(block.chainid),
                    "/adapter/",
                    vm.toString(adapter)
                );
            }
            vm.writeLine(outputScriptFileName, line);
            line = "";
        }
    }

    function formatConfig(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0.00";

        string memory result = vm.toString(value);
        uint256 len = bytes(result).length;
        while (len < 4) {
            result = string.concat("0", result);
            ++len;
        }

        if (value % 10 > 0) {
            result = string.concat("0.", _substring(result, 0, 4));
        } else if (value % 100 > 0) {
            result = string.concat("0.", _substring(result, 0, 3));
        } else {
            result = string.concat("0.", _substring(result, 0, 2));
        }

        return result;
    }

    function formatPercentage(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0.00%";

        string memory result = vm.toString(value);
        uint256 len = bytes(result).length;

        if (len < 2) {
            result = string.concat("0.0", result, "%");
        } else if (len < 3) {
            result = string.concat("0.", result, "%");
        } else {
            result = string.concat(_substring(result, 0, len - 2), ".", _substring(result, len - 2, len), "%");
        }

        return result;
    }

    function formatAmount(uint256 amount, uint256 decimals) internal pure returns (string memory) {
        if (amount == 0) return "0";

        // Convert to string
        string memory result = vm.toString(amount);
        uint256 len = bytes(result).length;

        // If amount is smaller than decimals, pad with leading zeros
        while (len < decimals) {
            result = string.concat("0", result);
            ++len;
        }

        // If decimals is 0, return as is
        if (decimals == 0) return result;

        // Split into whole and fractional parts
        string memory whole;
        string memory fraction;

        if (len <= decimals) {
            whole = "0";
            fraction = result; // Already padded to correct length
        } else {
            whole = _substring(result, 0, len - decimals);
            fraction = _substring(result, len - decimals, len);
        }

        // Trim trailing zeros from fraction
        bytes memory fractionBytes = bytes(fraction);
        uint256 lastNonZero = decimals;
        while (lastNonZero > 0 && fractionBytes[lastNonZero - 1] == "0") {
            lastNonZero--;
        }

        // If no significant digits after decimal, return just the whole part
        if (lastNonZero == 0) {
            return whole;
        }

        // Otherwise return with decimal point and significant fractional digits
        return string.concat(whole, ".", _substring(fraction, 0, lastNonZero));
    }
}
