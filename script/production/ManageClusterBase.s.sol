// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {CrossAdapter} from "euler-price-oracle/adapter/CrossAdapter.sol";
import {BatchBuilder, Vm, console} from "../utils/ScriptUtils.s.sol";
import {SafeTransaction, SafeUtil} from "../utils/SafeUtils.s.sol";
import {IRMLens} from "../../src/Lens/IRMLens.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {KinkIRMDeployer} from "../04_IRM.s.sol";
import {EVaultDeployer, OracleRouterDeployer, EulerRouter} from "../07_EVault.s.sol";
import {OracleLens} from "../../src/Lens/OracleLens.sol";
import {StubOracle} from "../utils/StubOracle.sol";
import "evk/EVault/shared/Constants.sol";
import "../../src/Lens/LensTypes.sol";

abstract contract ManageClusterBase is BatchBuilder {
    struct Cluster {
        string clusterAddressesPath;
        address oracleRoutersGovernor;
        address vaultsGovernor;
        address[] assets;
        address[] vaults;
        bool[] vaultUpgradable;
        address[] oracleRouters;
        uint32 rampDuration;
        uint16[][] ltvs;
        uint16[][] borrowLTVsOverride;
        address[] externalVaults;
        uint16[][] externalLTVs;
        uint16[][] externalBorrowLTVsOverride;
        uint16 spreadLTV;
        uint16[][] spreadLTVOverride;
        uint16[][] externalSpreadLTVsOverride;
        address unitOfAccount;
        address feeReceiver;
        uint16 interestFee;
        uint16 maxLiquidationDiscount;
        uint16 liquidationCoolOffTime;
        address hookTarget;
        uint32 hookedOps;
        uint32 configFlags;
        bool forceZeroGovernors;
        mapping(address asset => string provider) oracleProviders;
        mapping(address asset => uint256 supplyCapNoDecimals) supplyCaps;
        mapping(address asset => bool supplyCapEncoded) supplyCapEncoded;
        mapping(address asset => uint256 borrowCapNoDecimals) borrowCaps;
        mapping(address asset => bool borrowCapEncoded) borrowCapEncoded;
        mapping(address asset => address feeReceiverOverride) feeReceiverOverride;
        mapping(address asset => uint16 interestFeeOverride) interestFeeOverride;
        mapping(address asset => uint16 maxLiquidationDiscountOverride) maxLiquidationDiscountOverride;
        mapping(address asset => uint16 liquidationCoolOffTimeOverride) liquidationCoolOffTimeOverride;
        mapping(address asset => address hookTargetOverride) hookTargetOverride;
        mapping(address asset => uint32 hookedOpsOverride) hookedOpsOverride;
        mapping(address asset => uint32 configFlagsOverride) configFlagsOverride;
        mapping(address asset => uint256[4] kinkIRMParams) kinkIRMParams;
        mapping(
            uint256 baseRate
                => mapping(uint256 slope1 => mapping(uint256 slope2 => mapping(uint256 kink => address irm)))
        ) kinkIRMMap;
        mapping(address asset => address irm) irms;
        address[] irmsArr;
        address stubOracle;
    }

    struct Params {
        address vault;
        address[] collaterals;
        uint16[] liquidationLTVs;
        uint16[] borrowLTVsOverride;
        uint16[] spreadLTVs;
    }

    Cluster internal cluster;
    mapping(address router => mapping(address vault => mapping(address asset => bool resolved))) internal
        pendingResolvedVaults;
    mapping(address router => mapping(address base => mapping(address quote => bool set))) internal
        pendingConfiguredAdapters;
    mapping(address router => bool transferred) internal pendingGovernanceTransfer;
    TimelockCall[] internal pendingTimelockCalls;

    modifier initialize() {
        defineCluster();
        loadCluster();
        configureCluster();
        encodeAmountCaps(cluster.assets, cluster.supplyCaps, cluster.supplyCapEncoded);
        encodeAmountCaps(cluster.assets, cluster.borrowCaps, cluster.borrowCapEncoded);

        checkClusterDataSanity();
        simulatePendingTransactions();

        _;

        dumpCluster();
        postOperations();
    }

    function run() public initialize {
        if (isEmergency()) emergencyMode();
        else managementMode();
    }

    function managementMode() public {
        // deploy the stub oracle (needed in case pull oracle is meant to be used as it might be stale)
        if (cluster.stubOracle == address(0) && !isNoStubOracle()) {
            startBroadcast();
            cluster.stubOracle = address(new StubOracle());
            stopBroadcast();
        }

        // deploy the oracle router
        {
            OracleRouterDeployer deployer = new OracleRouterDeployer();
            address oracleRouter;
            for (uint256 i = 0; i < cluster.assets.length; ++i) {
                // deploy only one router if needed and reuse it for other to be deployed vaults
                if (cluster.vaults[i] == address(0) && cluster.oracleRouters[i] == address(0)) {
                    if (oracleRouter == address(0)) {
                        oracleRouter = deployer.deploy(peripheryAddresses.oracleRouterFactory);

                        // if the rest of the configuration will be carried out through safe, immediately transfer the
                        // governance over this router from the deployer to the safe or the final governor
                        if (isBatchViaSafe()) {
                            addBatchItem(
                                oracleRouter,
                                getDeployer(),
                                abi.encodeCall(
                                    EulerRouter(oracleRouter).transferGovernance,
                                    (getTimelock() == address(0) ? getSafe() : cluster.oracleRoutersGovernor)
                                )
                            );
                        }
                    }

                    cluster.oracleRouters[i] = oracleRouter;
                }
            }
        }

        // deploy the vaults
        {
            EVaultDeployer deployer = new EVaultDeployer();
            for (uint256 i = 0; i < cluster.assets.length; ++i) {
                // only deploy undefined yet vaults
                if (cluster.vaults[i] == address(0)) {
                    cluster.vaults[i] = deployer.deploy(
                        coreAddresses.eVaultFactory,
                        cluster.vaultUpgradable[i],
                        cluster.assets[i],
                        cluster.oracleRouters[i],
                        cluster.unitOfAccount
                    );

                    // if the rest of the configuration will be carried out through safe, immediately transfer the
                    // governance over this vault from the deployer to the safe or the final governor
                    if (isBatchViaSafe()) {
                        addBatchItem(
                            cluster.vaults[i],
                            getDeployer(),
                            abi.encodeCall(
                                IEVault(cluster.vaults[i]).setGovernorAdmin,
                                (getTimelock() == address(0) ? getSafe() : cluster.vaultsGovernor)
                            )
                        );
                    }
                }
            }
        }

        // execute the EVC batch as the deployer to transfer the governance
        executeBatchDirectly(false);

        // deploy the IRMs
        {
            KinkIRMDeployer deployer = new KinkIRMDeployer();
            for (uint256 i = 0; i < cluster.assets.length; ++i) {
                address asset = cluster.assets[i];
                uint256[4] storage p = cluster.kinkIRMParams[asset];
                address irm;

                if (p[0] != 0 || p[1] != 0 || p[2] != 0 || p[3] != 0) {
                    irm = cluster.kinkIRMMap[p[0]][p[1]][p[2]][p[3]];
                } else if (cluster.irms[asset] == address(0)) {
                    irm = cluster.irmsArr[i];
                } else {
                    irm = cluster.irms[asset];
                }

                // only deploy those IRMs that haven't been deployed or cached yet
                if (irm == address(0) && (p[0] != 0 || p[1] != 0 || p[2] != 0 || p[3] != 0)) {
                    irm = deployer.deploy(peripheryAddresses.kinkIRMFactory, p[0], p[1], p[2], uint32(p[3]));
                    cluster.kinkIRMMap[p[0]][p[1]][p[2]][p[3]] = irm;
                }

                cluster.irms[cluster.assets[i]] = cluster.irmsArr[i] = irm;
            }
        }

        // configure the vaults and the oracle routers
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            address vault = cluster.vaults[i];
            address asset = IEVault(vault).asset();

            // configure the vault by checking if current configuration differs from desired.
            // recognize potential overrides applicable per asset
            {
                address feeReceiver = IEVault(vault).feeReceiver();
                if (
                    cluster.feeReceiverOverride[asset] != address(uint160(type(uint160).max))
                        && feeReceiver != cluster.feeReceiverOverride[asset]
                ) {
                    setFeeReceiver(vault, cluster.feeReceiverOverride[asset]);
                } else if (
                    cluster.feeReceiverOverride[asset] == address(uint160(type(uint160).max))
                        && feeReceiver != cluster.feeReceiver
                ) {
                    setFeeReceiver(vault, cluster.feeReceiver);
                }
            }

            {
                uint16 interestFee = IEVault(vault).interestFee();
                if (
                    cluster.interestFeeOverride[asset] != type(uint16).max
                        && interestFee != cluster.interestFeeOverride[asset]
                ) {
                    setInterestFee(vault, cluster.interestFeeOverride[asset]);
                } else if (cluster.interestFeeOverride[asset] == type(uint16).max && interestFee != cluster.interestFee)
                {
                    setInterestFee(vault, cluster.interestFee);
                }
            }

            {
                uint16 maxLiquidationDiscount = IEVault(vault).maxLiquidationDiscount();
                if (
                    cluster.maxLiquidationDiscountOverride[asset] != type(uint16).max
                        && maxLiquidationDiscount != cluster.maxLiquidationDiscountOverride[asset]
                ) {
                    setMaxLiquidationDiscount(vault, cluster.maxLiquidationDiscountOverride[asset]);
                } else if (
                    cluster.maxLiquidationDiscountOverride[asset] == type(uint16).max
                        && maxLiquidationDiscount != cluster.maxLiquidationDiscount
                ) {
                    setMaxLiquidationDiscount(vault, cluster.maxLiquidationDiscount);
                }
            }

            {
                uint16 liquidationCoolOffTime = IEVault(vault).liquidationCoolOffTime();
                if (
                    cluster.liquidationCoolOffTimeOverride[asset] != type(uint16).max
                        && liquidationCoolOffTime != cluster.liquidationCoolOffTimeOverride[asset]
                ) {
                    setLiquidationCoolOffTime(vault, cluster.liquidationCoolOffTimeOverride[asset]);
                } else if (
                    cluster.liquidationCoolOffTimeOverride[asset] == type(uint16).max
                        && liquidationCoolOffTime != cluster.liquidationCoolOffTime
                ) {
                    setLiquidationCoolOffTime(vault, cluster.liquidationCoolOffTime);
                }
            }

            {
                uint32 configFlags = IEVault(vault).configFlags();
                if (
                    cluster.configFlagsOverride[asset] != type(uint32).max
                        && configFlags != cluster.configFlagsOverride[asset]
                ) {
                    setConfigFlags(vault, cluster.configFlagsOverride[asset]);
                } else if (cluster.configFlagsOverride[asset] == type(uint32).max && configFlags != cluster.configFlags)
                {
                    setConfigFlags(vault, cluster.configFlags);
                }
            }

            {
                (uint16 supplyCap, uint16 borrowCap) = IEVault(vault).caps();
                if (supplyCap != cluster.supplyCaps[asset] || borrowCap != cluster.borrowCaps[asset]) {
                    setCaps(vault, cluster.supplyCaps[asset], cluster.borrowCaps[asset]);
                }
            }

            if (IEVault(vault).interestRateModel() != cluster.irms[asset]) {
                setInterestRateModel(vault, cluster.irms[asset]);
            }

            setLTVsAndConfigureOracleRouter(
                Params({
                    vault: vault,
                    collaterals: cluster.vaults,
                    liquidationLTVs: getLTVs(cluster.ltvs, i),
                    borrowLTVsOverride: getLTVs(cluster.borrowLTVsOverride, i),
                    spreadLTVs: getSpreadLTVs(cluster.spreadLTVOverride, cluster.spreadLTV, i)
                })
            );

            setLTVsAndConfigureOracleRouter(
                Params({
                    vault: vault,
                    collaterals: cluster.externalVaults,
                    liquidationLTVs: getLTVs(cluster.externalLTVs, i),
                    borrowLTVsOverride: getLTVs(cluster.externalBorrowLTVsOverride, i),
                    spreadLTVs: getSpreadLTVs(cluster.externalSpreadLTVsOverride, cluster.spreadLTV, i)
                })
            );

            {
                (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
                address newHookTarget;
                uint32 newHookedOps;

                if (
                    cluster.hookTargetOverride[asset] != address(uint160(type(uint160).max))
                        && hookTarget != cluster.hookTargetOverride[asset]
                ) {
                    newHookTarget = cluster.hookTargetOverride[asset];
                } else if (
                    cluster.hookTargetOverride[asset] == address(uint160(type(uint160).max))
                        && hookTarget != cluster.hookTarget
                ) {
                    newHookTarget = cluster.hookTarget;
                } else {
                    newHookTarget = hookTarget;
                }

                if (
                    cluster.hookedOpsOverride[asset] != type(uint32).max
                        && hookedOps != cluster.hookedOpsOverride[asset]
                ) {
                    newHookedOps = cluster.hookedOpsOverride[asset];
                } else if (cluster.hookedOpsOverride[asset] == type(uint32).max && hookedOps != cluster.hookedOps) {
                    newHookedOps = cluster.hookedOps;
                } else {
                    newHookedOps = hookedOps;
                }

                if (newHookTarget != hookTarget || newHookedOps != hookedOps) {
                    setHookConfig(vault, newHookTarget, newHookedOps);
                }
            }

            if (IEVault(vault).governorAdmin() != cluster.vaultsGovernor) {
                setGovernorAdmin(vault, cluster.vaultsGovernor);
            }
        }

        // transfer the oracle router governance
        for (uint256 i = 0; i < cluster.oracleRouters.length; ++i) {
            address oracleRouter = cluster.oracleRouters[i];
            if (
                !pendingGovernanceTransfer[oracleRouter] && isValidOracleRouter(oracleRouter)
                    && EulerRouter(oracleRouter).governor() != cluster.oracleRoutersGovernor
            ) {
                transferGovernance(oracleRouter, cluster.oracleRoutersGovernor);
                pendingGovernanceTransfer[oracleRouter] = true;
            }
        }

        executeBatch();
    }

    function emergencyMode() public {
        address emergencyVault = getEmergencyVaultAddress();

        if (isEmergencyLTVCollateral()) {
            address[] memory collaterals;

            if (emergencyVault == address(0)) {
                collaterals = new address[](cluster.vaults.length + cluster.externalVaults.length);
                for (uint256 i = 0; i < cluster.vaults.length; ++i) {
                    collaterals[i] = cluster.vaults[i];
                }
                for (uint256 i = 0; i < cluster.externalVaults.length; ++i) {
                    collaterals[cluster.vaults.length + i] = cluster.externalVaults[i];
                }
            } else {
                collaterals = new address[](1);
                collaterals[0] = emergencyVault;
            }

            for (uint256 i = 0; i < collaterals.length; ++i) {
                address collateral = collaterals[i];

                for (uint256 j = 0; j < cluster.vaults.length; ++j) {
                    address vault = cluster.vaults[j];
                    (uint16 borrowLTV, uint16 liquidationLTV,, uint48 targetTimestamp,) =
                        IEVault(vault).LTVFull(collateral);

                    if (borrowLTV == 0) continue;

                    setLTV(
                        vault,
                        collateral,
                        0,
                        liquidationLTV,
                        targetTimestamp <= block.timestamp ? 0 : uint32(targetTimestamp - block.timestamp)
                    );
                }
            }
        }

        if (isEmergencyLTVBorrowing()) {
            address[] memory vaults;

            if (emergencyVault == address(0)) {
                vaults = new address[](cluster.vaults.length);
                for (uint256 i = 0; i < cluster.vaults.length; ++i) {
                    vaults[i] = cluster.vaults[i];
                }
            } else {
                vaults = new address[](1);
                vaults[0] = emergencyVault;
            }

            for (uint256 i = 0; i < vaults.length; ++i) {
                address vault = vaults[i];
                address[] memory collaterals = IEVault(vault).LTVList();

                for (uint256 j = 0; j < collaterals.length; ++j) {
                    address collateral = collaterals[j];
                    (uint16 borrowLTV, uint16 liquidationLTV,, uint48 targetTimestamp,) =
                        IEVault(vault).LTVFull(collateral);

                    if (borrowLTV == 0) continue;

                    setLTV(
                        vault,
                        collateral,
                        0,
                        liquidationLTV,
                        targetTimestamp <= block.timestamp ? 0 : uint32(targetTimestamp - block.timestamp)
                    );
                }
            }
        }

        if (isEmergencyCaps()) {
            address[] memory vaults;

            if (emergencyVault == address(0)) {
                vaults = new address[](cluster.vaults.length);
                for (uint256 i = 0; i < cluster.vaults.length; ++i) {
                    vaults[i] = cluster.vaults[i];
                }
            } else {
                vaults = new address[](1);
                vaults[0] = emergencyVault;
            }

            for (uint256 i = 0; i < vaults.length; ++i) {
                address vault = vaults[i];
                uint256 decimals = IEVault(vault).decimals();
                (uint16 supplyCap, uint16 borrowCap) = IEVault(vault).caps();

                if (supplyCap != decimals || borrowCap != decimals) {
                    setCaps(vault, uint16(decimals), uint16(decimals));
                }
            }
        }

        if (isEmergencyOperations()) {
            address[] memory vaults;

            if (emergencyVault == address(0)) {
                vaults = new address[](cluster.vaults.length);
                for (uint256 i = 0; i < cluster.vaults.length; ++i) {
                    vaults[i] = cluster.vaults[i];
                }
            } else {
                vaults = new address[](1);
                vaults[0] = emergencyVault;
            }

            for (uint256 i = 0; i < vaults.length; ++i) {
                address vault = vaults[i];
                (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();

                if (hookTarget != address(0) || hookedOps != OP_MAX_VALUE) {
                    setHookConfig(vault, address(0), OP_MAX_VALUE);
                }
            }
        }

        executeBatch();
    }

    function defineCluster() internal virtual;
    function configureCluster() internal virtual;
    function postOperations() internal virtual {}

    function computeRouterConfiguration(address base, address quote, string memory provider)
        private
        view
        returns (address, address, bool)
    {
        if (base == quote || _strEq(provider, "")) return (base, address(0), false);

        address adapter = getValidAdapter(base, quote, provider);
        bool useStub = false;

        if (_strEq("ExternalVault|", _substring(provider, 0, bytes("ExternalVault|").length))) {
            base = IEVault(base).asset();
        }

        if (adapter != address(0)) {
            string memory name = EulerRouter(adapter).name();
            if (_strEq(name, "PythOracle") || _strEq(name, "RedstoneCoreOracle")) {
                useStub = true;
            } else if (_strEq(name, "CrossAdapter")) {
                address baseCross = CrossAdapter(adapter).oracleBaseCross();
                address crossBase = CrossAdapter(adapter).oracleCrossQuote();

                name = EulerRouter(baseCross).name();
                if (_strEq(name, "PythOracle") || _strEq(name, "RedstoneCoreOracle") || _strEq(name, "CrossAdapter")) {
                    useStub = true;
                } else {
                    name = EulerRouter(crossBase).name();
                    if (
                        _strEq(name, "PythOracle") || _strEq(name, "RedstoneCoreOracle") || _strEq(name, "CrossAdapter")
                    ) {
                        useStub = true;
                    }
                }
            }
        }

        return (base, adapter, useStub && !isNoStubOracle());
    }

    // sets LTVs for all passed collaterals of the vault and configures the oracle router
    function setLTVsAndConfigureOracleRouter(Params memory p) private {
        address oracleRouter = IEVault(p.vault).oracle();
        address unitOfAccount = IEVault(p.vault).unitOfAccount();

        if (isBorrowable(p)) {
            address asset = IEVault(p.vault).asset();
            (address base, address adapter,) =
                computeRouterConfiguration(asset, unitOfAccount, cluster.oracleProviders[asset]);

            // in case the vault asset is a valid external vault, resolve it in the router
            if (
                asset != base && !pendingResolvedVaults[oracleRouter][asset][base] && isValidOracleRouter(oracleRouter)
                    && EulerRouter(oracleRouter).resolvedVaults(asset) != base
            ) {
                govSetResolvedVault(oracleRouter, asset, true);
                pendingResolvedVaults[oracleRouter][asset][base] = true;
            }

            // configure the oracle for the vault asset or the asset of the vault asset
            if (
                !pendingConfiguredAdapters[oracleRouter][base][unitOfAccount] && isValidOracleRouter(oracleRouter)
                    && (adapter != address(0) || isForceZeroOracle())
                    && EulerRouter(oracleRouter).getConfiguredOracle(base, unitOfAccount) != adapter
            ) {
                govSetConfig(oracleRouter, base, unitOfAccount, adapter);
                pendingConfiguredAdapters[oracleRouter][base][unitOfAccount] = true;
            }
        }

        for (uint256 i = 0; i < p.collaterals.length; ++i) {
            address collateral = p.collaterals[i];
            address collateralAsset = IEVault(collateral).asset();

            (address base, address adapter, bool useStub) =
                computeRouterConfiguration(collateralAsset, unitOfAccount, cluster.oracleProviders[collateralAsset]);
            (uint16 borrowLTV, uint16 liquidationLTV) = computeLTVs(p, i);
            (uint16 currentBorrowLTV, uint16 targetLiquidationLTV,,,) = IEVault(p.vault).LTVFull(collateral);

            // configure the oracle router for the collateral before setting the LTV. recognize potentially pending
            // transactions by looking up pendingResolvedVaults and pendingConfiguredAdapters mappings

            if (currentBorrowLTV > 0 || borrowLTV > 0 || liquidationLTV > 0 || targetLiquidationLTV > 0) {
                // resolve the collateral vault in the router to be able to convert shares to assets
                if (
                    !pendingResolvedVaults[oracleRouter][collateral][collateralAsset]
                        && isValidOracleRouter(oracleRouter)
                        && EulerRouter(oracleRouter).resolvedVaults(collateral) != collateralAsset
                ) {
                    govSetResolvedVault(oracleRouter, collateral, true);
                    pendingResolvedVaults[oracleRouter][collateral][collateralAsset] = true;
                }

                // in case the collateral vault asset is a valid external vault, resolve it in the router
                if (
                    collateralAsset != base && !pendingResolvedVaults[oracleRouter][collateralAsset][base]
                        && isValidOracleRouter(oracleRouter)
                        && EulerRouter(oracleRouter).resolvedVaults(collateralAsset) != base
                ) {
                    govSetResolvedVault(oracleRouter, collateralAsset, true);
                    pendingResolvedVaults[oracleRouter][collateralAsset][base] = true;
                }

                // configure the oracle for the collateral vault asset or the asset of the collateral vault asset
                if (
                    !pendingConfiguredAdapters[oracleRouter][base][unitOfAccount] && isValidOracleRouter(oracleRouter)
                        && (adapter != address(0) || isForceZeroOracle())
                        && EulerRouter(oracleRouter).getConfiguredOracle(base, unitOfAccount) != adapter
                ) {
                    govSetConfig(oracleRouter, base, unitOfAccount, adapter);
                    pendingConfiguredAdapters[oracleRouter][base][unitOfAccount] = true;
                }
            }

            // disregard the current liquidation LTV if currently ramping down, only compare target LTVs to figure out
            // if setting the LTV is required
            if (currentBorrowLTV != borrowLTV || targetLiquidationLTV != liquidationLTV) {
                // in case the stub oracle has to be used, append the following batch critical section:
                // configure the stub oracle, set LTV, configure the desired oracle
                if (useStub && liquidationLTV != 0 && isValidOracleRouter(oracleRouter)) {
                    govSetConfig_critical(oracleRouter, base, unitOfAccount, cluster.stubOracle);

                    setLTV_critical(
                        p.vault,
                        collateral,
                        borrowLTV,
                        liquidationLTV,
                        liquidationLTV >= targetLiquidationLTV ? 0 : cluster.rampDuration
                    );

                    govSetConfig_critical(oracleRouter, base, unitOfAccount, adapter);

                    appendCriticalSectionToBatch();
                } else {
                    setLTV(
                        p.vault,
                        collateral,
                        borrowLTV,
                        liquidationLTV,
                        liquidationLTV >= targetLiquidationLTV ? 0 : cluster.rampDuration
                    );
                }
            }
        }
    }

    // extracts LTVs column for a given vault from the LTVs matrix
    function getLTVs(uint16[][] memory ltvs, uint256 vaultIndex) private pure returns (uint16[] memory) {
        require(ltvs.length == 0 || ltvs[0].length > vaultIndex, "getLTVs: Invalid vault index");

        uint16[] memory vaultLTVs = new uint16[](ltvs.length);
        for (uint256 i = 0; i < ltvs.length; ++i) {
            vaultLTVs[i] = ltvs[i][vaultIndex];
        }
        return vaultLTVs;
    }

    function getSpreadLTVs(uint16[][] memory spreadLTVs, uint16 spreadLTV, uint256 vaultIndex)
        private
        pure
        returns (uint16[] memory)
    {
        require(spreadLTVs.length == 0 || spreadLTVs[0].length > vaultIndex, "getSpreadLTVs: Invalid vault index");

        uint16[] memory vaultSpreadLTVs = new uint16[](spreadLTVs.length);
        for (uint256 i = 0; i < spreadLTVs.length; ++i) {
            vaultSpreadLTVs[i] = spreadLTVs[i][vaultIndex] == type(uint16).max ? spreadLTV : spreadLTVs[i][vaultIndex];
        }
        return vaultSpreadLTVs;
    }

    function computeLTVs(Params memory p, uint256 i) private pure returns (uint16 borrowLTV, uint16 liquidationLTV) {
        liquidationLTV = p.liquidationLTVs[i];

        if (p.borrowLTVsOverride[i] != type(uint16).max) {
            borrowLTV = liquidationLTV < p.borrowLTVsOverride[i] ? liquidationLTV : p.borrowLTVsOverride[i];
        } else {
            borrowLTV = liquidationLTV > p.spreadLTVs[i] ? liquidationLTV - p.spreadLTVs[i] : 0;
        }

        return (borrowLTV, liquidationLTV);
    }

    function isBorrowable(Params memory p) private view returns (bool) {
        for (uint256 i = 0; i < p.collaterals.length; ++i) {
            (uint16 borrowLTV, uint16 liquidationLTV) = computeLTVs(p, i);
            if (borrowLTV > 0 || liquidationLTV > 0) return true;

            (uint16 currentBorrowLTV, uint16 targetLiquidationLTV,,,) = IEVault(p.vault).LTVFull(p.collaterals[i]);
            if (currentBorrowLTV > 0 || targetLiquidationLTV > 0) return true;
        }

        return false;
    }

    function dumpCluster() private {
        string memory result = "";
        result = vm.serializeAddress("cluster", "oracleRouters", cluster.oracleRouters);
        result = vm.serializeAddress("cluster", "vaults", cluster.vaults);
        result = vm.serializeAddress("cluster", "irms", cluster.irmsArr);
        result = vm.serializeAddress("cluster", "externalVaults", cluster.externalVaults);
        result = vm.serializeAddress("cluster", "stubOracle", cluster.stubOracle);

        vm.writeJson(result, string.concat(vm.projectRoot(), "/script/Cluster.json"));

        if (isBroadcast()) {
            if (!_strEq(cluster.clusterAddressesPath, "")) vm.writeJson(result, cluster.clusterAddressesPath);
        }
    }

    function loadDefaults() private {}

    function loadTimelockCalls() internal {}

    function loadCluster() private {
        if (!_strEq(cluster.clusterAddressesPath, "")) {
            cluster.clusterAddressesPath = string.concat(vm.projectRoot(), cluster.clusterAddressesPath);

            if (vm.exists(cluster.clusterAddressesPath)) {
                string memory json = vm.readFile(cluster.clusterAddressesPath);
                cluster.oracleRouters = getAddressesFromJson(json, ".oracleRouters");
                cluster.vaults = getAddressesFromJson(json, ".vaults");
                cluster.irmsArr = getAddressesFromJson(json, ".irms");
                cluster.externalVaults = getAddressesFromJson(json, ".externalVaults");
                cluster.stubOracle = getAddressFromJson(json, ".stubOracle");
            }
        }

        cluster.vaultUpgradable = new bool[](cluster.assets.length);
        for (uint256 i = 0; i < cluster.assets.length; ++i) {
            cluster.vaultUpgradable[i] =
                cluster.vaults.length == 0 || i >= cluster.vaults.length || cluster.vaults[i] == address(0)
                    ? true
                    : GenericFactory(coreAddresses.eVaultFactory).getProxyConfig(cluster.vaults[i]).upgradeable;
        }

        for (uint256 i = 0; i < cluster.irmsArr.length; ++i) {
            InterestRateModelDetailedInfo memory irmInfo =
                IRMLens(lensAddresses.irmLens).getInterestRateModelInfo(cluster.irmsArr[i]);

            if (irmInfo.interestRateModelType == InterestRateModelType.KINK) {
                KinkIRMInfo memory kinkIRMInfo = abi.decode(irmInfo.interestRateModelParams, (KinkIRMInfo));
                cluster.kinkIRMMap[kinkIRMInfo.baseRate][kinkIRMInfo.slope1][kinkIRMInfo.slope2][kinkIRMInfo.kink] =
                    cluster.irmsArr[i];
            }
        }

        if (cluster.vaults.length == 0) {
            cluster.vaults = new address[](cluster.assets.length);
        }

        if (cluster.oracleRouters.length == 0) {
            cluster.oracleRouters = new address[](cluster.assets.length);
        }

        if (cluster.irmsArr.length == 0) {
            cluster.irmsArr = new address[](cluster.assets.length);
        }

        for (uint256 i = 0; i < cluster.assets.length; ++i) {
            address asset = cluster.assets[i];
            cluster.feeReceiverOverride[asset] = address(uint160(type(uint160).max));
            cluster.interestFeeOverride[asset] = type(uint16).max;
            cluster.maxLiquidationDiscountOverride[asset] = type(uint16).max;
            cluster.liquidationCoolOffTimeOverride[asset] = type(uint16).max;
            cluster.hookTargetOverride[asset] = address(uint160(type(uint160).max));
            cluster.hookedOpsOverride[asset] = type(uint32).max;
            cluster.configFlagsOverride[asset] = type(uint32).max;
        }

        cluster.borrowLTVsOverride = new uint16[][](cluster.assets.length);
        for (uint256 i = 0; i < cluster.borrowLTVsOverride.length; ++i) {
            cluster.borrowLTVsOverride[i] = new uint16[](cluster.assets.length);
            for (uint256 j = 0; j < cluster.borrowLTVsOverride[i].length; ++j) {
                cluster.borrowLTVsOverride[i][j] = type(uint16).max;
            }
        }

        cluster.externalBorrowLTVsOverride = new uint16[][](cluster.externalVaults.length);
        for (uint256 i = 0; i < cluster.externalBorrowLTVsOverride.length; ++i) {
            cluster.externalBorrowLTVsOverride[i] = new uint16[](cluster.assets.length);
            for (uint256 j = 0; j < cluster.externalBorrowLTVsOverride[i].length; ++j) {
                cluster.externalBorrowLTVsOverride[i][j] = type(uint16).max;
            }
        }

        cluster.spreadLTVOverride = new uint16[][](cluster.assets.length);
        for (uint256 i = 0; i < cluster.spreadLTVOverride.length; ++i) {
            cluster.spreadLTVOverride[i] = new uint16[](cluster.assets.length);
            for (uint256 j = 0; j < cluster.spreadLTVOverride[i].length; ++j) {
                cluster.spreadLTVOverride[i][j] = type(uint16).max;
            }
        }

        cluster.externalSpreadLTVsOverride = new uint16[][](cluster.externalVaults.length);
        for (uint256 i = 0; i < cluster.externalSpreadLTVsOverride.length; ++i) {
            cluster.externalSpreadLTVsOverride[i] = new uint16[](cluster.assets.length);
            for (uint256 j = 0; j < cluster.externalSpreadLTVsOverride[i].length; ++j) {
                cluster.externalSpreadLTVsOverride[i][j] = type(uint16).max;
            }
        }
    }

    function checkClusterDataSanity() private view {
        require(cluster.vaults.length == cluster.assets.length, "Vaults and assets length mismatch");
        require(
            cluster.vaultUpgradable.length == cluster.assets.length,
            "Vaults upgradable array and assets length mismatch"
        );
        require(cluster.oracleRouters.length == cluster.assets.length, "OracleRouters and assets length mismatch");
        require(cluster.irmsArr.length == cluster.assets.length, "IRMs and assets length mismatch");
        require(cluster.ltvs.length == cluster.assets.length, "LTVs and assets length mismatch");
        require(
            cluster.externalLTVs.length == cluster.externalVaults.length,
            "Auxiliary LTVs and auxiliary vaults length mismatch"
        );

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            require(
                cluster.vaults[i] == address(0) || cluster.assets[i] == IEVault(cluster.vaults[i]).asset(),
                "Vault asset mismatch"
            );
        }

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            require(
                cluster.vaults[i] == address(0) || (cluster.oracleRouters[i] == IEVault(cluster.vaults[i]).oracle()),
                "Oracle Router mismatch"
            );
        }

        for (uint256 i = 0; i < cluster.externalVaults.length; ++i) {
            require(cluster.externalVaults[i] != address(0), "External vault cannot be zero address");
        }

        for (uint256 i = 0; i < cluster.ltvs.length; ++i) {
            require(cluster.ltvs[i].length == cluster.assets.length, "LTVs and assets length mismatch");
        }

        for (uint256 i = 0; i < cluster.externalLTVs.length; ++i) {
            require(cluster.externalLTVs[i].length == cluster.assets.length, "External LTVs and assets length mismatch");
        }

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            if (cluster.vaults[i] == address(0)) continue;

            address[] memory collaterals = IEVault(cluster.vaults[i]).LTVList();

            for (uint256 j = 0; j < collaterals.length; ++j) {
                if (IEVault(cluster.vaults[i]).LTVBorrow(collaterals[j]) == 0) continue;

                bool found = false;
                for (uint256 k = 0; k < cluster.vaults.length; ++k) {
                    if (collaterals[j] == cluster.vaults[k]) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    for (uint256 k = 0; k < cluster.externalVaults.length; ++k) {
                        if (collaterals[j] == cluster.externalVaults[k]) {
                            found = true;
                            break;
                        }
                    }
                }
                require(found, "Borrow LTV found for non-existent collateral");
            }
        }

        if (getCheckPhasedOutVaults()) {
            for (uint256 i = 0; i < cluster.vaults.length; ++i) {
                bool notPhasedOut;

                for (uint256 j = 0; j < cluster.vaults.length; ++j) {
                    if (IEVault(cluster.vaults[i]).LTVLiquidation(cluster.vaults[j]) > 0) {
                        notPhasedOut = true;
                        break;
                    }
                }

                for (uint256 j = 0; j < cluster.vaults.length; ++j) {
                    if (IEVault(cluster.vaults[j]).LTVLiquidation(cluster.vaults[i]) > 0) {
                        notPhasedOut = true;
                        break;
                    }
                }

                if (!notPhasedOut) {
                    console.log("Phased out vault found: %s %s", cluster.vaults[i], IEVault(cluster.vaults[i]).symbol());
                }
            }

            for (uint256 i = 0; i < cluster.externalVaults.length; ++i) {
                bool notPhasedOut;

                for (uint256 j = 0; j < cluster.vaults.length; ++j) {
                    if (IEVault(cluster.vaults[j]).LTVLiquidation(cluster.externalVaults[i]) > 0) {
                        notPhasedOut = true;
                        break;
                    }
                }

                if (!notPhasedOut) {
                    console.log(
                        "Phased out external vault found: %s %s",
                        cluster.externalVaults[i],
                        IEVault(cluster.externalVaults[i]).symbol()
                    );
                }
            }
        }

        require(bytes(cluster.clusterAddressesPath).length != 0, "Invalid cluster addresses path");
        require(
            cluster.forceZeroGovernors
                || (cluster.oracleRoutersGovernor != address(0) && cluster.vaultsGovernor != address(0)),
            "Invalid governors"
        );
        require(cluster.unitOfAccount != address(0), "Invalid unit of account");
    }

    function simulatePendingTransactions() internal {
        if (isSkipPendingSimulation()) return;

        SafeTransaction safeUtil = new SafeTransaction();
        if (!safeUtil.isTransactionServiceAPIAvailable()) return;

        address safe = getSimulateSafe();
        if (safe != address(0)) {
            vm.recordLogs();
            console.log("Simulating pending safe transactions");
            SafeTransaction.TransactionSimple[] memory transactions = safeUtil.getPendingTransactions(safe);

            for (uint256 i = 0; i < transactions.length; ++i) {
                try safeUtil.simulate(
                    transactions[i].operation == SafeUtil.Operation.CALL,
                    transactions[i].safe,
                    transactions[i].to,
                    transactions[i].value,
                    transactions[i].data
                ) {} catch {
                    console.log("Error simulating pending safe transaction");
                }
            }
        }

        address payable timelock = payable(getSimulateTimelock());
        if (timelock != address(0)) {
            console.log("Simulating pending timelock transactions");

            bytes32[] memory topic = new bytes32[](1);
            topic[0] = keccak256("CallScheduled(bytes32,uint256,address,uint256,bytes,bytes32,uint256)");

            uint256 intervals;
            uint256 fromBlock;
            {
                uint256 timeDiff = block.timestamp;
                vm.createSelectFork(getDeploymentRpcUrl(), block.number - 1e4);
                timeDiff -= block.timestamp;
                selectFork(block.chainid);

                intervals = TimelockController(timelock).getMinDelay() / timeDiff + 5;
                fromBlock = block.number - intervals * 1e4;
            }

            while (intervals > 0) {
                Vm.EthGetLogs[] memory ethLogs = vm.eth_getLogs(fromBlock, fromBlock + 1e4, timelock, topic);

                for (uint256 i = 0; i < ethLogs.length; ++i) {
                    bytes32 id = ethLogs[i].topics[1];

                    if (!TimelockController(timelock).isOperationPending(id)) continue;

                    (address target, uint256 value, bytes memory data, bytes32 predecessor,) =
                        abi.decode(ethLogs[i].data, (address, uint256, bytes, bytes32, uint256));

                    vm.store(timelock, keccak256(abi.encode(uint256(id), uint256(1))), bytes32(block.timestamp));

                    vm.deal(getDeployer(), value);
                    vm.prank(getDeployer());
                    try TimelockController(timelock).execute(target, value, data, predecessor, bytes32(0)) {}
                    catch {
                        console.log("Error executing already scheduled timelock transaction");
                    }
                }

                fromBlock += 1e4;
                intervals--;
            }

            Vm.Log[] memory logs = vm.getRecordedLogs();
            for (uint256 i = 0; i < logs.length; ++i) {
                if (
                    timelock != logs[i].emitter || logs[i].topics.length < 2 || topic[0] != logs[i].topics[0]
                        || !TimelockController(timelock).isOperationPending(logs[i].topics[1])
                ) continue;

                (address target, uint256 value, bytes memory data, bytes32 predecessor,) =
                    abi.decode(logs[i].data, (address, uint256, bytes, bytes32, uint256));

                bytes32 id = logs[i].topics[1];
                vm.store(timelock, keccak256(abi.encode(uint256(id), uint256(1))), bytes32(uint256(block.timestamp)));

                vm.deal(getDeployer(), value);
                vm.prank(getDeployer());
                try TimelockController(timelock).execute(target, value, data, predecessor, bytes32(0)) {}
                catch {
                    console.log("Error executing not yet scheduled timelock transaction");
                }
            }
        }
    }
}
