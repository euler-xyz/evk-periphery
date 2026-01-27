// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, console} from "./utils/ScriptUtils.s.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {ILayerZeroEndpointV2, IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";

interface IEndpointV2 is ILayerZeroEndpointV2 {
    function delegates(address oapp) external view returns (address);
}

contract OwnershipTransferCore is BatchBuilder {
    uint256 internal constant HUB_CHAIN_ID = 1;

    function run() public {
        verifyMultisigAddresses(multisigAddresses);

        address privilegedAddress = ProtocolConfig(coreAddresses.protocolConfig).admin();
        if (privilegedAddress != multisigAddresses.DAO) {
            if (privilegedAddress == getDeployer()) {
                console.log("+ Setting ProtocolConfig admin to address %s", multisigAddresses.DAO);
                startBroadcast();
                ProtocolConfig(coreAddresses.protocolConfig).setAdmin(multisigAddresses.DAO);
                stopBroadcast();
            } else {
                console.log("! ProtocolConfig admin is not the caller of this script. Skipping...");
            }
        } else {
            console.log("- ProtocolConfig admin is already set to the desired address. Skipping...");
        }

        if (
            ProtocolConfig(coreAddresses.protocolConfig).feeReceiver() != peripheryAddresses.feeFlowController
                && peripheryAddresses.feeFlowController != address(0)
        ) {
            console.log("! ProtocolConfig fee receiver is not the FeeFlowController address yet. Remember to set it!");
        }

        {
            bytes32 defaultAdminRole =
                AccessControl(governorAddresses.eVaultFactoryTimelockController).DEFAULT_ADMIN_ROLE();

            if (
                AccessControl(governorAddresses.eVaultFactoryTimelockController).hasRole(
                    defaultAdminRole, getDeployer()
                )
            ) {
                console.log(
                    "+ Renouncing EVaultFactoryTimelockController default admin role from the caller of this script %s",
                    getDeployer()
                );
                startBroadcast();
                AccessControl(governorAddresses.eVaultFactoryTimelockController).renounceRole(
                    defaultAdminRole, getDeployer()
                );
                stopBroadcast();
            } else {
                console.log(
                    "- The caller of this script is no longer the default admin of the EVaultFactoryTimelockController. Skipping..."
                );
            }
        }

        {
            bytes32 defaultAdminRole = AccessControl(governorAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE();

            if (
                !AccessControl(governorAddresses.eVaultFactoryGovernor).hasRole(
                    defaultAdminRole, governorAddresses.eVaultFactoryTimelockController
                )
            ) {
                if (AccessControl(governorAddresses.eVaultFactoryGovernor).hasRole(defaultAdminRole, getDeployer())) {
                    console.log(
                        "+ Granting FactoryGovernor default admin role to address %s",
                        governorAddresses.eVaultFactoryTimelockController
                    );
                    startBroadcast();
                    AccessControl(governorAddresses.eVaultFactoryGovernor).grantRole(
                        defaultAdminRole, governorAddresses.eVaultFactoryTimelockController
                    );
                    stopBroadcast();
                } else {
                    console.log("! FactoryGovernor default admin role is not the caller of this script. Skipping...");
                }
            } else {
                console.log("- FactoryGovernor default admin role is already set to the desired address. Skipping...");
            }

            if (AccessControl(governorAddresses.eVaultFactoryGovernor).hasRole(defaultAdminRole, getDeployer())) {
                console.log(
                    "+ Renouncing FactoryGovernor default admin role from the caller of this script %s", getDeployer()
                );
                startBroadcast();
                AccessControl(governorAddresses.eVaultFactoryGovernor).renounceRole(defaultAdminRole, getDeployer());
                stopBroadcast();
            } else {
                console.log(
                    "- The caller of this script is no longer the default admin of the FactoryGovernor. Skipping..."
                );
            }
        }

        privilegedAddress = GenericFactory(coreAddresses.eVaultFactory).upgradeAdmin();
        if (privilegedAddress != governorAddresses.eVaultFactoryGovernor) {
            if (privilegedAddress == getDeployer()) {
                console.log(
                    "+ Setting EVaultFactory upgrade admin to the EVaultFactoryGovernor address %s",
                    governorAddresses.eVaultFactoryGovernor
                );
                startBroadcast();
                GenericFactory(coreAddresses.eVaultFactory).setUpgradeAdmin(governorAddresses.eVaultFactoryGovernor);
                stopBroadcast();
            } else {
                console.log("! EVaultFactory upgrade admin is not the caller of this script. Skipping...");
            }
        } else {
            console.log("- EVaultFactory upgrade admin is already set to the desired address. Skipping...");
        }

        if (coreAddresses.eulerEarnFactory != address(0)) {
            privilegedAddress = Ownable(coreAddresses.eulerEarnFactory).owner();
            if (privilegedAddress != multisigAddresses.DAO) {
                if (privilegedAddress == getDeployer()) {
                    console.log("+ Transferring ownership of EulerEarnFactory to %s", multisigAddresses.DAO);
                    transferOwnership(coreAddresses.eulerEarnFactory, multisigAddresses.DAO);
                } else {
                    console.log("! EulerEarnFactory owner is not the caller of this script. Skipping...");
                }
            } else {
                console.log("- EulerEarnFactory owner is already set to the desired address. Skipping...");
            }
        } else {
            console.log("! EulerEarnFactory is not deployed yet. Skipping...");
        }

        if (block.chainid != HUB_CHAIN_ID) {
            transferERC20BurnableMintableOwnership("EUL", tokenAddresses.EUL, multisigAddresses.DAO);
        }

        privilegedAddress = Ownable(tokenAddresses.rEUL).owner();
        if (privilegedAddress != multisigAddresses.labs) {
            if (privilegedAddress == getDeployer()) {
                console.log("+ Transferring ownership of rEUL to %s", multisigAddresses.labs);
                transferOwnership(tokenAddresses.rEUL, multisigAddresses.labs);
            } else {
                console.log("! rEUL owner is not the caller of this script. Skipping...");
            }
        } else {
            console.log("- rEUL owner is already set to the desired address. Skipping...");
        }

        if (tokenAddresses.eUSD != address(0)) {
            transferERC20BurnableMintableOwnership(
                "eUSD",
                tokenAddresses.eUSD,
                governorAddresses.eUSDAdminTimelockController == address(0)
                    ? multisigAddresses.DAO
                    : governorAddresses.eUSDAdminTimelockController
            );
        } else {
            console.log("! eUSD is not deployed yet. Skipping...");
        }

        if (tokenAddresses.seUSD != address(0) && block.chainid != HUB_CHAIN_ID) {
            transferERC20BurnableMintableOwnership("seUSD", tokenAddresses.seUSD, multisigAddresses.DAO);
        } else {
            console.log("! seUSD is not deployed yet. Skipping...");
        }

        if (bridgeAddresses.eulOFTAdapter != address(0)) {
            transferOFTAdapterOwnership("EUL", bridgeAddresses.eulOFTAdapter);
        } else {
            console.log("! EUL OFT Adapter is not deployed yet. Skipping...");
        }

        if (bridgeAddresses.eusdOFTAdapter != address(0)) {
            transferOFTAdapterOwnership("eUSD", bridgeAddresses.eusdOFTAdapter);
        } else {
            console.log("! eUSD OFT Adapter is not deployed yet. Skipping...");
        }

        if (bridgeAddresses.seusdOFTAdapter != address(0)) {
            transferOFTAdapterOwnership("seUSD", bridgeAddresses.seusdOFTAdapter);
        } else {
            console.log("! seUSD OFT Adapter is not deployed yet. Skipping...");
        }

        if (governorAddresses.eUSDAdminTimelockController != address(0)) {
            bytes32 defaultAdminRole = AccessControl(governorAddresses.eUSDAdminTimelockController).DEFAULT_ADMIN_ROLE();

            if (AccessControl(governorAddresses.eUSDAdminTimelockController).hasRole(defaultAdminRole, getDeployer())) {
                console.log(
                    "+ Renouncing eUSDAdminTimelockController default admin role from the caller of this script %s",
                    getDeployer()
                );
                startBroadcast();
                AccessControl(governorAddresses.eUSDAdminTimelockController).renounceRole(
                    defaultAdminRole, getDeployer()
                );
                stopBroadcast();
            } else {
                console.log(
                    "- The caller of this script is no longer the default admin of the eUSDAdminTimelockController. Skipping..."
                );
            }
        }

        if (peripheryAddresses.feeCollector != address(0)) {
            bytes32 defaultAdminRole = AccessControl(peripheryAddresses.feeCollector).DEFAULT_ADMIN_ROLE();

            startBroadcast();
            if (!AccessControl(peripheryAddresses.feeCollector).hasRole(defaultAdminRole, multisigAddresses.DAO)) {
                if (AccessControl(peripheryAddresses.feeCollector).hasRole(defaultAdminRole, getDeployer())) {
                    console.log("+ Granting FeeCollector default admin role to address %s", multisigAddresses.DAO);
                    AccessControl(peripheryAddresses.feeCollector).grantRole(defaultAdminRole, multisigAddresses.DAO);
                } else {
                    console.log("! FeeCollector default admin role is not the caller of this script. Skipping...");
                }
            } else {
                console.log("- FeeCollector default admin role is already set to the desired address. Skipping...");
            }

            if (AccessControl(peripheryAddresses.feeCollector).hasRole(defaultAdminRole, getDeployer())) {
                console.log(
                    "+ Renouncing FeeCollector default admin role from the caller of this script %s", getDeployer()
                );
                AccessControl(peripheryAddresses.feeCollector).renounceRole(defaultAdminRole, getDeployer());
            } else {
                console.log("- The caller of this script is no longer the default admin of FeeCollector. Skipping...");
            }
            stopBroadcast();
        } else {
            console.log("! FeeCollector is not deployed yet. Skipping...");
        }

        executeBatch();
    }

    function transferERC20BurnableMintableOwnership(string memory tokenName, address token, address desiredAdmin)
        internal
    {
        bytes32 defaultAdminRole = AccessControl(token).DEFAULT_ADMIN_ROLE();

        startBroadcast();
        if (!AccessControl(token).hasRole(defaultAdminRole, desiredAdmin)) {
            if (AccessControl(token).hasRole(defaultAdminRole, getDeployer())) {
                console.log("+ Granting %s default admin role to address %s", tokenName, desiredAdmin);
                AccessControl(token).grantRole(defaultAdminRole, desiredAdmin);
            } else {
                console.log("! %s default admin role is not the caller of this script. Skipping...", tokenName);
            }
        } else {
            console.log("- %s default admin role is already set to the desired address. Skipping...", tokenName);
        }

        if (AccessControl(token).hasRole(defaultAdminRole, getDeployer())) {
            console.log(
                "+ Renouncing %s default admin role from the caller of this script %s", tokenName, getDeployer()
            );
            AccessControl(token).renounceRole(defaultAdminRole, getDeployer());
        } else {
            console.log("- The caller of this script is no longer the default admin of %s. Skipping...", tokenName);
        }
        stopBroadcast();
    }

    function transferOFTAdapterOwnership(string memory tokenName, address adapter) internal {
        address privilegedAddress;

        if (block.chainid == HUB_CHAIN_ID && (_strEq(tokenName, "EUL") || _strEq(tokenName, "seUSD"))) {
            address proxyAdmin = address(
                uint160(uint256(vm.load(adapter, 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103)))
            );

            privilegedAddress = Ownable(proxyAdmin).owner();
            if (privilegedAddress != multisigAddresses.DAO) {
                if (privilegedAddress == getDeployer()) {
                    console.log(
                        "+ Transferring ownership of the %s OFTAdapterUpgradeable ProxyAdmin to %s",
                        tokenName,
                        multisigAddresses.DAO
                    );
                    startBroadcast();
                    Ownable(proxyAdmin).transferOwnership(multisigAddresses.DAO);
                    stopBroadcast();
                } else {
                    console.log(
                        "! %s OFTAdapterUpgradeable ProxyAdmin owner is not the caller of this script. Skipping...",
                        tokenName
                    );
                }
            } else {
                console.log(
                    "- %s OFTAdapterUpgradeable ProxyAdmin owner is already set to the desired address. Skipping...",
                    tokenName
                );
            }
        }

        privilegedAddress = IEndpointV2(address(IOAppCore(adapter).endpoint())).delegates(adapter);
        if (privilegedAddress != multisigAddresses.DAO) {
            if (Ownable(adapter).owner() == getDeployer()) {
                console.log("+ Transferring delegate of %s OFT Adapter to %s", tokenName, multisigAddresses.DAO);
                startBroadcast();
                IOAppCore(adapter).setDelegate(multisigAddresses.DAO);
                stopBroadcast();
            } else {
                console.log("! %s OFT Adapter owner is not the caller of this script. Skipping...", tokenName);
            }
        } else {
            console.log("- %s OFT Adapter delegate is already set to the desired address. Skipping...", tokenName);
        }

        privilegedAddress = Ownable(adapter).owner();
        if (privilegedAddress != multisigAddresses.DAO) {
            if (privilegedAddress == getDeployer()) {
                console.log("+ Transferring ownership of %s OFT Adapter to %s", tokenName, multisigAddresses.DAO);
                startBroadcast();
                Ownable(adapter).transferOwnership(multisigAddresses.DAO);
                stopBroadcast();
            } else {
                console.log("! %s OFT Adapter owner is not the caller of this script. Skipping...", tokenName);
            }
        } else {
            console.log("- %s OFT Adapter owner is already set to the desired address. Skipping...", tokenName);
        }
    }
}
