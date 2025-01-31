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
                    "+ Renouncing TimelockController default admin role from the caller of this script %s",
                    getDeployer()
                );
                startBroadcast();
                AccessControl(governorAddresses.eVaultFactoryTimelockController).renounceRole(
                    defaultAdminRole, getDeployer()
                );
                stopBroadcast();
            } else {
                console.log(
                    "- The caller of this script is no longer the default admin of the TimelockController. Skipping..."
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

        {
            bytes32 defaultAdminRole =
                AccessControl(governorAddresses.accessControlEmergencyGovernor).DEFAULT_ADMIN_ROLE();

            if (
                !AccessControl(governorAddresses.accessControlEmergencyGovernor).hasRole(
                    defaultAdminRole, multisigAddresses.DAO
                )
            ) {
                if (
                    AccessControl(governorAddresses.accessControlEmergencyGovernor).hasRole(
                        defaultAdminRole, getDeployer()
                    )
                ) {
                    console.log(
                        "+ Granting GovernorAccessControlEmergency default admin role to address %s",
                        multisigAddresses.DAO
                    );
                    grantRole(governorAddresses.accessControlEmergencyGovernor, defaultAdminRole, multisigAddresses.DAO);
                } else {
                    console.log(
                        "! GovernorAccessControlEmergency default admin role is not the caller of this script. Skipping..."
                    );
                }
            } else {
                console.log(
                    "- GovernorAccessControlEmergency default admin role is already set to the desired address. Skipping..."
                );
            }

            if (
                AccessControl(governorAddresses.accessControlEmergencyGovernor).hasRole(defaultAdminRole, getDeployer())
            ) {
                console.log(
                    "+ Renouncing GovernorAccessControlEmergency default admin role from the caller of this script %s",
                    getDeployer()
                );
                renounceRole(governorAddresses.accessControlEmergencyGovernor, defaultAdminRole, getDeployer());
            } else {
                console.log(
                    "- The caller of this script is no longer the default admin of the GovernorAccessControlEmergency. Skipping..."
                );
            }
        }

        if (block.chainid != 1) {
            bytes32 defaultAdminRole = AccessControl(tokenAddresses.EUL).DEFAULT_ADMIN_ROLE();

            startBroadcast();
            if (!AccessControl(tokenAddresses.EUL).hasRole(defaultAdminRole, multisigAddresses.DAO)) {
                if (AccessControl(tokenAddresses.EUL).hasRole(defaultAdminRole, getDeployer())) {
                    console.log("+ Granting EUL default admin role to address %s", multisigAddresses.DAO);
                    AccessControl(tokenAddresses.EUL).grantRole(defaultAdminRole, multisigAddresses.DAO);
                } else {
                    console.log("! EUL default admin role is not the caller of this script. Skipping...");
                }
            } else {
                console.log("- EUL default admin role is already set to the desired address. Skipping...");
            }

            if (AccessControl(tokenAddresses.EUL).hasRole(defaultAdminRole, getDeployer())) {
                console.log("+ Renouncing EUL default admin role from the caller of this script %s", getDeployer());
                AccessControl(tokenAddresses.EUL).renounceRole(defaultAdminRole, getDeployer());
            } else {
                console.log("- The caller of this script is no longer the default admin of EUL. Skipping...");
            }
            stopBroadcast();
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

        if (bridgeAddresses.oftAdapter != address(0)) {
            if (block.chainid == 1) {
                address proxyAdmin = address(
                    uint160(
                        uint256(
                            vm.load(
                                bridgeAddresses.oftAdapter,
                                0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
                            )
                        )
                    )
                );
                privilegedAddress = Ownable(proxyAdmin).owner();
                if (privilegedAddress != multisigAddresses.DAO) {
                    if (privilegedAddress == getDeployer()) {
                        console.log(
                            "+ Transferring ownership of OFTAdapterUpgradeable ProxyAdmin to %s", multisigAddresses.DAO
                        );
                        startBroadcast();
                        Ownable(proxyAdmin).transferOwnership(multisigAddresses.DAO);
                        stopBroadcast();
                    } else {
                        console.log(
                            "! OFTAdapterUpgradeable ProxyAdmin owner is not the caller of this script. Skipping..."
                        );
                    }
                } else {
                    console.log(
                        "- OFTAdapterUpgradeable ProxyAdmin owner is already set to the desired address. Skipping..."
                    );
                }
            }

            privilegedAddress = IEndpointV2(address(IOAppCore(bridgeAddresses.oftAdapter).endpoint())).delegates(
                bridgeAddresses.oftAdapter
            );
            if (privilegedAddress != multisigAddresses.DAO) {
                if (Ownable(bridgeAddresses.oftAdapter).owner() == getDeployer()) {
                    console.log("+ Transferring delegate of OFT Adapter to %s", multisigAddresses.DAO);
                    startBroadcast();
                    IOAppCore(bridgeAddresses.oftAdapter).setDelegate(multisigAddresses.DAO);
                    stopBroadcast();
                } else {
                    console.log("! OFT Adapter owner is not the caller of this script. Skipping...");
                }
            } else {
                console.log("- OFT Adapter delegate is already set to the desired address. Skipping...");
            }

            privilegedAddress = Ownable(bridgeAddresses.oftAdapter).owner();
            if (privilegedAddress != multisigAddresses.DAO) {
                if (privilegedAddress == getDeployer()) {
                    console.log("+ Transferring ownership of OFT Adapter to %s", multisigAddresses.DAO);
                    startBroadcast();
                    Ownable(bridgeAddresses.oftAdapter).transferOwnership(multisigAddresses.DAO);
                    stopBroadcast();
                } else {
                    console.log("! OFT Adapter owner is not the caller of this script. Skipping...");
                }
            } else {
                console.log("- OFT Adapter owner is already set to the desired address. Skipping...");
            }
        } else {
            console.log("! OFT Adapter is not deployed yet. Skipping...");
        }

        executeBatch();
    }
}
