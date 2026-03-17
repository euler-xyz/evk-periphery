// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, BatchBuilder, IEVC, IEVault, console} from "../utils/ScriptUtils.s.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";
import {SafeTransaction, SafeMultisendBuilder} from "../utils/SafeUtils.s.sol";
import {FactoryGovernor} from "../../src/Governor/FactoryGovernor.sol";
import {CapRiskSteward} from "../../src/Governor/CapRiskSteward.sol";
import {GovernorAccessControlEmergency} from "../../src/Governor/GovernorAccessControlEmergency.sol";
import {LayerZeroSendEUL} from "../utils/LayerZeroUtils.s.sol";
import {
    LensAccountDeployer,
    LensOracleDeployer,
    LensIRMDeployer,
    LensVaultDeployer,
    LensUtilsDeployer,
    LensEulerEarnVaultDeployer
} from "../08_Lenses.s.sol";
import {ERC20Synth} from "../../src/ERC20/deployed/ERC20Synth.sol";
import {VaultLens, VaultInfoFull} from "../../src/Lens/VaultLens.sol";
import {UtilsLens, VaultInfoERC4626} from "../../src/Lens/UtilsLens.sol";
import {AccountLens, AccountInfo, AccountMultipleVaultsInfo} from "../../src/Lens/AccountLens.sol";

contract GetVaultInfoERC4626 is ScriptUtils {
    function run(address vault) public view returns (VaultInfoERC4626 memory) {
        return UtilsLens(lensAddresses.utilsLens).getVaultInfoERC4626(vault);
    }
}

contract GetVaultInfoFull is ScriptUtils {
    function run(address vault) public view returns (VaultInfoFull memory) {
        return VaultLens(lensAddresses.vaultLens).getVaultInfoFull(vault);
    }
}

contract GetAccountInfo is ScriptUtils {
    function run(address account, address vault) public view returns (AccountInfo memory) {
        return AccountLens(lensAddresses.accountLens).getAccountInfo(account, vault);
    }
}

contract GetAccountEnabledVaultsInfo is ScriptUtils {
    function run(address account, address vault) public view returns (AccountMultipleVaultsInfo memory) {
        return AccountLens(lensAddresses.accountLens).getAccountEnabledVaultsInfo(account, vault);
    }
}

contract BridgeEULToLabsMultisig is ScriptUtils, SafeMultisendBuilder {
    function run(uint256 dstChainId, uint256 amountNoDecimals) public {
        uint256[] memory dstChainIds = new uint256[](1);
        uint256[] memory amountsNoDecimals = new uint256[](1);
        dstChainIds[0] = dstChainId;
        amountsNoDecimals[0] = amountNoDecimals;
        execute(dstChainIds, amountsNoDecimals);
    }

    function run(uint256[] memory dstChainIds, uint256[] memory amountsNoDecimals) public {
        require(
            dstChainIds.length == amountsNoDecimals.length,
            "dstChainIds and amountsNoDecimals must have the same length"
        );
        execute(dstChainIds, amountsNoDecimals);
    }

    function execute(uint256[] memory dstChainIds, uint256[] memory amountsNoDecimals) public {
        LayerZeroSendEUL util = new LayerZeroSendEUL();
        address safe = getSafe(false);

        for (uint256 i = 0; i < dstChainIds.length; ++i) {
            uint256 dstChainId = dstChainIds[i];
            uint256 amount = amountsNoDecimals[i] * 1e18;
            address dstAddress =
                deserializeMultisigAddresses(getAddressesJson("MultisigAddresses.json", dstChainId)).labs;

            if (safe == address(0)) {
                util.run(dstChainId, dstAddress, amount);
            } else {
                (address to, uint256 value, bytes memory rawCalldata) =
                    util.getSendCalldata(safe, dstChainId, dstAddress, amount, 1e4);
                addMultisendItem(tokenAddresses.EUL, abi.encodeCall(IERC20.approve, (to, amount)));
                addMultisendItem(to, value, rawCalldata);
            }
        }

        if (multisendItemExists()) executeMultisend(safe, safeNonce++, true, false);
    }
}

contract MigratePosition is BatchBuilder {
    function run() public {
        uint8[] memory sourceIds = new uint8[](1);
        uint8[] memory destinationIds = new uint8[](1);

        sourceIds[0] = getSourceAccountId();
        destinationIds[0] = getDestinationAccountId();

        execute(sourceIds, destinationIds);
    }

    function run(uint8[] calldata sourceIds, uint8[] calldata destinationIds) public {
        execute(sourceIds, destinationIds);
    }

    function execute(uint8[] memory sourceIds, uint8[] memory destinationIds) public {
        require(
            sourceIds.length == destinationIds.length && sourceIds.length > 0,
            "sourceIds and destinationIds must have the same length and be non-empty"
        );

        address sourceWallet = getSourceWallet();
        bytes19 sourceWalletPrefix = IEVC(coreAddresses.evc).getAddressPrefix(sourceWallet);
        address destinationWallet = getDestinationWallet();

        uint256 bitfield;
        for (uint8 i = 0; i < sourceIds.length; ++i) {
            bitfield |= 1 << sourceIds[i];
        }

        for (uint8 i = 0; i < sourceIds.length; ++i) {
            _migratePosition(sourceWallet, sourceIds[i], destinationWallet, destinationIds[i]);
        }

        string memory result = string.concat(
            "IMPORTANT: before proceeding, you must trust the destination wallet ",
            vm.toString(destinationWallet),
            "!\n\n"
        );
        result = string.concat(result, "Step 1: give control over your account to the destination wallet\n");
        result = string.concat(
            result,
            "Go to the block explorer dedicated to your network and paste the EVC address: ",
            vm.toString(coreAddresses.evc),
            "\n"
        );
        result = string.concat(
            result,
            "Click 'Contract' and then 'Write Contract'. Find 'setOperator' function. Paste the following input data:\n"
        );
        result = string.concat(result, "    setOperator/payableAmount: 0\n");
        result = string.concat(result, "    addressPrefix: ", _substring(vm.toString(sourceWalletPrefix), 0, 40), "\n");
        result = string.concat(result, "    operator: ", vm.toString(destinationWallet), "\n");
        result = string.concat(result, "    operatorBitField: ", vm.toString(bitfield), "\n");
        result = string.concat(result, "Connect your source wallet, click 'Write' and execute the transaction.\n\n");
        result = string.concat(result, "Step 2: pull the position from the source account to the destination account\n");
        result = string.concat(
            result,
            "Go to the block explorer dedicated to your network and paste the EVC address: ",
            vm.toString(coreAddresses.evc),
            "\n"
        );
        result = string.concat(
            result,
            "Click 'Contract' and then 'Write Contract'. Find 'batch' function. Paste the following input data:\n"
        );
        result = string.concat(result, "    batch/payableAmount: 0\n");
        result = string.concat(result, "    items: ", toString(getBatchItems()), "\n");
        result = string.concat(result, "Connect your destination wallet, click 'Write' and execute the transaction.\n");

        console.log(result);
        vm.writeFile(string.concat(vm.projectRoot(), "/script/MigrationInstruction.txt"), result);

        // simulation
        vm.prank(sourceWallet);
        IEVC(coreAddresses.evc).setOperator(sourceWalletPrefix, destinationWallet, bitfield);

        if (isBatchViaSafe()) {
            executeBatchViaSafe(false);
        } else {
            dumpBatch(destinationWallet);
            executeBatchPrank(destinationWallet);
        }
    }

    function _migratePosition(
        address sourceWallet,
        uint8 sourceAccountId,
        address destinationWallet,
        uint8 destinationAccountId
    ) internal {
        address sourceAccount = address(uint160(sourceWallet) ^ sourceAccountId);
        address destinationAccount = address(uint160(destinationWallet) ^ destinationAccountId);
        address[] memory collaterals = IEVC(coreAddresses.evc).getCollaterals(sourceAccount);
        address[] memory controllers = IEVC(coreAddresses.evc).getControllers(sourceAccount);

        for (uint256 i = 0; i < collaterals.length; ++i) {
            if (IEVault(collaterals[i]).balanceOf(sourceAccount) == 0) continue;

            addBatchItem(
                coreAddresses.evc,
                address(0),
                abi.encodeCall(IEVC.enableCollateral, (destinationAccount, collaterals[i]))
            );
            addBatchItem(
                collaterals[i],
                sourceAccount,
                abi.encodeCall(IEVault(collaterals[i]).transferFromMax, (sourceAccount, destinationAccount))
            );
            addBatchItem(
                coreAddresses.evc, address(0), abi.encodeCall(IEVC.disableCollateral, (sourceAccount, collaterals[i]))
            );
        }

        for (uint256 i = 0; i < controllers.length; ++i) {
            if (IEVault(controllers[i]).debtOf(sourceAccount) == 0) continue;

            addBatchItem(
                coreAddresses.evc,
                address(0),
                abi.encodeCall(IEVC.enableController, (destinationAccount, controllers[i]))
            );
            addBatchItem(
                controllers[i],
                destinationAccount,
                abi.encodeCall(IEVault(controllers[i]).pullDebt, (type(uint256).max, sourceAccount))
            );
            addBatchItem(controllers[i], sourceAccount, abi.encodeCall(IEVault(controllers[i]).disableController, ()));
        }

        addBatchItem(
            coreAddresses.evc,
            address(0),
            abi.encodeCall(IEVC.setAccountOperator, (sourceAccount, destinationWallet, false))
        );
    }
}

contract MergeSafeBatchBuilderFiles is ScriptUtils, SafeMultisendBuilder {
    function run() public {
        address safe = getSafe();
        string memory basePath = string.concat(
            vm.projectRoot(), "/", getPath(), "/SafeBatchBuilder_", vm.toString(safeNonce), "_", vm.toString(safe), "_"
        );

        for (uint256 i = 0; vm.exists(string.concat(basePath, vm.toString(i), ".json")); i++) {
            string memory json = vm.readFile(string.concat(basePath, vm.toString(i), ".json"));
            address target = vm.parseJsonAddress(json, ".transactions[0].to");
            uint256 value = vm.parseJsonUint(json, ".transactions[0].value");
            bytes memory data = vm.parseJsonBytes(json, ".transactions[0].data");

            addMultisendItem(target, value, data);
        }

        executeMultisend(safe, safeNonce++);
    }
}

contract UnpauseEVaultFactory is BatchBuilder {
    function run() public {
        SafeTransaction transaction = new SafeTransaction();

        transaction.create(
            true,
            getSafe(),
            governorAddresses.eVaultFactoryGovernor,
            0,
            abi.encodeCall(FactoryGovernor.unpause, (coreAddresses.eVaultFactory)),
            safeNonce++
        );
    }
}

contract DeployAndConfigureCRSAndGACE is BatchBuilder {
    function run() public {
        require(getConfigAddress("riskSteward") != address(0), "Risk steward config address not found");
        require(getConfigAddress("gauntlet") != address(0), "Gauntlet config address not found");

        startBroadcast();
        CapRiskSteward capRiskSteward = new CapRiskSteward(
            governorAddresses.accessControlEmergencyGovernor,
            peripheryAddresses.kinkIRMFactory,
            getDeployer(),
            2e18,
            1 days
        );

        governorAddresses.capRiskSteward = address(capRiskSteward);

        capRiskSteward.grantRole(capRiskSteward.WILD_CARD(), getConfigAddress("riskSteward"));
        capRiskSteward.grantRole(capRiskSteward.DEFAULT_ADMIN_ROLE(), multisigAddresses.DAO);
        capRiskSteward.renounceRole(capRiskSteward.DEFAULT_ADMIN_ROLE(), getDeployer());

        stopBroadcast();

        SafeTransaction transaction = new SafeTransaction();
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory payloads = new bytes[](2);

        targets[0] = governorAddresses.accessControlEmergencyGovernorWildcardTimelockController;
        values[0] = 0;
        payloads[0] = abi.encodeCall(
            AccessControl.grantRole,
            (
                TimelockController(payable(governorAddresses.accessControlEmergencyGovernorWildcardTimelockController))
                    .PROPOSER_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[1] = governorAddresses.accessControlEmergencyGovernorWildcardTimelockController;
        values[1] = 0;
        payloads[1] = abi.encodeCall(
            AccessControl.grantRole,
            (
                TimelockController(payable(governorAddresses.accessControlEmergencyGovernorWildcardTimelockController))
                    .CANCELLER_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        bytes memory data = abi.encodeCall(
            TimelockController.scheduleBatch,
            (
                targets,
                values,
                payloads,
                bytes32(0),
                bytes32(0),
                TimelockController(payable(governorAddresses.accessControlEmergencyGovernorWildcardTimelockController))
                    .getMinDelay()
            )
        );

        transaction.create(
            true,
            getSafe(),
            governorAddresses.accessControlEmergencyGovernorWildcardTimelockController,
            0,
            data,
            safeNonce++
        );

        // simulate timelock execution
        for (uint256 i = 0; i < targets.length; i++) {
            vm.prank(governorAddresses.accessControlEmergencyGovernorWildcardTimelockController);
            (bool success,) = targets[i].call{value: values[i]}(payloads[i]);
            require(success, "timelock execution simulation failed");
        }

        targets = new address[](5);
        values = new uint256[](5);
        payloads = new bytes[](5);

        targets[0] = governorAddresses.accessControlEmergencyGovernor;
        values[0] = 0;
        payloads[0] = abi.encodeCall(
            AccessControl.grantRole,
            (
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).CAPS_EMERGENCY_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[1] = governorAddresses.accessControlEmergencyGovernor;
        values[1] = 0;
        payloads[1] = abi.encodeCall(
            AccessControl.grantRole,
            (
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).LTV_EMERGENCY_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[2] = governorAddresses.accessControlEmergencyGovernor;
        values[2] = 0;
        payloads[2] = abi.encodeCall(
            AccessControl.grantRole,
            (
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).HOOK_EMERGENCY_ROLE(),
                getConfigAddress("gauntlet")
            )
        );

        targets[3] = governorAddresses.accessControlEmergencyGovernor;
        values[3] = 0;
        payloads[3] =
            abi.encodeCall(AccessControl.grantRole, (IGovernance.setCaps.selector, governorAddresses.capRiskSteward));

        targets[4] = governorAddresses.accessControlEmergencyGovernor;
        values[4] = 0;
        payloads[4] = abi.encodeCall(
            AccessControl.grantRole, (IGovernance.setInterestRateModel.selector, governorAddresses.capRiskSteward)
        );

        data = abi.encodeCall(
            TimelockController.scheduleBatch,
            (
                targets,
                values,
                payloads,
                bytes32(0),
                bytes32(0),
                TimelockController(payable(governorAddresses.accessControlEmergencyGovernorAdminTimelockController))
                    .getMinDelay()
            )
        );

        transaction.create(
            true, getSafe(), governorAddresses.accessControlEmergencyGovernorAdminTimelockController, 0, data, safeNonce
        );

        // simulate timelock execution
        for (uint256 i = 0; i < targets.length; i++) {
            vm.prank(governorAddresses.accessControlEmergencyGovernorAdminTimelockController);
            (bool success,) = targets[i].call{value: values[i]}(payloads[i]);
            require(success, "timelock execution simulation failed");
        }

        saveAddresses();
    }
}

contract RedeployAccountLens is BatchBuilder {
    function run() public {
        LensAccountDeployer deployer = new LensAccountDeployer();
        lensAddresses.accountLens = deployer.deploy();
        saveAddresses();
    }
}

contract RedeployOracleUtilsAndVaultLenses is BatchBuilder {
    function run() public {
        {
            LensOracleDeployer deployer = new LensOracleDeployer();
            lensAddresses.oracleLens = deployer.deploy(peripheryAddresses.oracleAdapterRegistry);
        }
        {
            LensUtilsDeployer deployer = new LensUtilsDeployer();
            lensAddresses.utilsLens = deployer.deploy(coreAddresses.eVaultFactory, lensAddresses.oracleLens);
        }
        {
            LensVaultDeployer deployer = new LensVaultDeployer();
            lensAddresses.vaultLens =
                deployer.deploy(lensAddresses.oracleLens, lensAddresses.utilsLens, lensAddresses.irmLens);
        }
        {
            LensEulerEarnVaultDeployer deployer = new LensEulerEarnVaultDeployer();
            lensAddresses.eulerEarnVaultLens = deployer.deploy(lensAddresses.utilsLens);
        }

        saveAddresses();
    }
}

contract LiquidateAccount is BatchBuilder {
    function run(address account, address collateral) public {
        execute(account, collateral);
    }

    function checkLiquidation(address account, address collateral)
        public
        view
        returns (uint256 maxRepay, uint256 maxYield)
    {
        (maxRepay, maxYield) = IEVault(IEVC(coreAddresses.evc).getControllers(account)[0])
            .checkLiquidation(getDeployer(), account, collateral);
    }

    function execute(address account, address collateral) internal {
        address[] memory controllers = IEVC(coreAddresses.evc).getControllers(account);

        if (controllers.length == 0) {
            console.log("No controllers enabled for account %s", account);
            return;
        }

        addBatchItem(
            coreAddresses.evc, address(0), abi.encodeCall(IEVC.enableController, (getDeployer(), controllers[0]))
        );
        addBatchItem(coreAddresses.evc, address(0), abi.encodeCall(IEVC.enableCollateral, (getDeployer(), collateral)));
        addBatchItem(
            controllers[0],
            abi.encodeCall(IEVault(controllers[0]).liquidate, (account, collateral, type(uint256).max, 0))
        );
        executeBatch();
    }
}

contract eUSDAllocate is BatchBuilder {
    function run(address vault, uint256 amount) public {
        execute(vault, uint128(amount));
    }

    function execute(address vault, uint128 amount) internal {
        bytes32 allocatorRole = ERC20Synth(tokenAddresses.eUSD).ALLOCATOR_ROLE();
        bool isAllocator = ERC20Synth(tokenAddresses.eUSD).hasRole(allocatorRole, getAppropriateOnBehalfOfAccount());

        addBatchItem(
            tokenAddresses.eUSD, abi.encodeCall(ERC20Synth.setCapacity, (getAppropriateOnBehalfOfAccount(), amount))
        );

        addBatchItem(tokenAddresses.eUSD, abi.encodeCall(ERC20Synth.mint, (tokenAddresses.eUSD, amount)));

        if (!isAllocator) {
            addBatchItem(
                tokenAddresses.eUSD,
                abi.encodeCall(ERC20Synth.grantRole, (allocatorRole, getAppropriateOnBehalfOfAccount()))
            );
        }

        addBatchItem(tokenAddresses.eUSD, abi.encodeCall(ERC20Synth.allocate, (vault, amount)));

        if (!isAllocator) {
            addBatchItem(
                tokenAddresses.eUSD,
                abi.encodeCall(ERC20Synth.revokeRole, (allocatorRole, getAppropriateOnBehalfOfAccount()))
            );
        }

        executeBatch();
    }
}
