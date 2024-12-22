// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {CrossAdapter} from "euler-price-oracle/adapter/CrossAdapter.sol";
import {BatchBuilder} from "../utils/ScriptUtils.s.sol";
import {SafeTransaction, SafeUtil} from "../utils/SafeUtils.s.sol";
import {IRMLens} from "../../src/Lens/IRMLens.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {KinkIRM} from "../04_IRM.s.sol";
import {EVaultDeployer, OracleRouterDeployer, EulerRouter} from "../07_EVault.s.sol";
import {OracleLens} from "../../src/Lens/OracleLens.sol";
import {StubOracle} from "../utils/StubOracle.sol";
import "../../src/Lens/LensTypes.sol";

abstract contract ManageClusterBase is BatchBuilder {
    struct Cluster {
        string clusterAddressesPath;
        address oracleRoutersGovernor;
        address vaultsGovernor;
        address[] assets;
        address[] vaults;
        address[] oracleRouters;
        uint32 rampDuration;
        uint16[][] ltvs;
        address[] externalVaults;
        uint16[][] externalLTVs;
        uint16 spreadLTV;
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
        mapping(address asset => uint256 borrowCapNoDecimals) borrowCaps;
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
        address[] irms;
        address stubOracle;
    }

    Cluster internal cluster;
    mapping(address router => mapping(address vault => mapping(address asset => bool resolved))) internal
        pendingResolvedVaults;
    mapping(address router => mapping(address base => mapping(address quote => bool set))) internal
        pendingConfiguredAdapters;
    mapping(address router => bool transferred) internal pendingGovernanceTransfer;

    modifier initialize() {
        vm.pauseGasMetering();

        configureCluster();
        encodeAmountCaps(cluster.assets, cluster.supplyCaps);
        encodeAmountCaps(cluster.assets, cluster.borrowCaps);

        loadCluster();
        checkClusterDataSanity();
        simulatePendingTransactions();
        preOperations();

        _;

        dumpCluster();
        postOperations();
    }

    function run() public initialize {
        // deploy the stub oracle (needed in case pull oracle is meant to be used as it might be stale)
        if (cluster.stubOracle == address(0)) {
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

                        // if the rest of the configuration will be carried out through safe,
                        // immediately transfer the governance over this router from the deployer to the safe
                        if (isBatchViaSafe()) {
                            addBatchItem(
                                oracleRouter,
                                getDeployer(),
                                abi.encodeCall(EulerRouter(oracleRouter).transferGovernance, (getSafe()))
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
                        true,
                        cluster.assets[i],
                        cluster.oracleRouters[i],
                        cluster.unitOfAccount
                    );

                    // if the rest of the configuration will be carried out through safe,
                    // immediately transfer the governance over this vault from the deployer to the safe
                    if (isBatchViaSafe()) {
                        addBatchItem(
                            cluster.vaults[i],
                            getDeployer(),
                            abi.encodeCall(IEVault(cluster.vaults[i]).setGovernorAdmin, (getSafe()))
                        );
                    }
                }
            }
        }

        // execute the EVC batch as the deployer to transfer the governance
        executeBatchDirectly();

        // deploy the IRMs
        {
            KinkIRM deployer = new KinkIRM();
            for (uint256 i = 0; i < cluster.assets.length; ++i) {
                uint256[4] storage p = cluster.kinkIRMParams[cluster.assets[i]];
                address irm = cluster.kinkIRMMap[p[0]][p[1]][p[2]][p[3]];

                // only deploy those IRMs that haven't been deployed or cached yet
                if (irm == address(0) && (p[0] != 0 || p[1] != 0 || p[2] != 0 || p[3] != 0)) {
                    irm = deployer.deploy(peripheryAddresses.kinkIRMFactory, p[0], p[1], p[2], uint32(p[3]));
                    cluster.kinkIRMMap[p[0]][p[1]][p[2]][p[3]] = irm;
                }

                cluster.irms[i] = irm;
            }
        }

        // configure the vaults and the oracle routers
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            address vault = cluster.vaults[i];
            address asset = IEVault(vault).asset();

            // configure the oracle router for the vault asset by checking if current configuration differs from
            // desired.
            // recognize potentially pending transactions by looking up pendingResolvedVaults and
            // pendingConfiguredAdapters mappings
            {
                address oracleRouter = cluster.oracleRouters[i];
                address unitOfAccount = IEVault(vault).unitOfAccount();
                (address base, address adapter,) =
                    computeRouterConfiguration(asset, unitOfAccount, cluster.oracleProviders[asset]);

                // in case the vault asset is a valid external vault, resolve it in the router
                if (
                    asset != base && !pendingResolvedVaults[oracleRouter][asset][base]
                        && EulerRouter(oracleRouter).resolvedVaults(asset) != base
                ) {
                    govSetResolvedVault(oracleRouter, asset, true);
                    pendingResolvedVaults[oracleRouter][asset][base] = true;
                }

                // configure the oracle for the vault asset or the asset of the vault asset
                if (
                    !pendingConfiguredAdapters[oracleRouter][base][unitOfAccount]
                        && EulerRouter(oracleRouter).getConfiguredOracle(base, unitOfAccount) != adapter
                ) {
                    govSetConfig(oracleRouter, base, unitOfAccount, adapter);
                    pendingConfiguredAdapters[oracleRouter][base][unitOfAccount] = true;
                }
            }

            // configure the vault by checking if current configuration differs from desired.
            // recognize potential overrides applicable per asset
            {
                address feeReceiver = IEVault(vault).feeReceiver();
                if (
                    cluster.feeReceiverOverride[asset] != address(uint160(type(uint160).max))
                        && feeReceiver != cluster.feeReceiverOverride[asset]
                ) {
                    setFeeReceiver(vault, cluster.feeReceiverOverride[asset]);
                } else if (feeReceiver != cluster.feeReceiver) {
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
                } else if (interestFee != cluster.interestFee) {
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
                } else if (maxLiquidationDiscount != cluster.maxLiquidationDiscount) {
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
                } else if (liquidationCoolOffTime != cluster.liquidationCoolOffTime) {
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
                } else if (configFlags != cluster.configFlags) {
                    setConfigFlags(vault, cluster.configFlags);
                }
            }

            {
                (uint16 supplyCap, uint16 borrowCap) = IEVault(vault).caps();
                if (supplyCap != cluster.supplyCaps[asset] || borrowCap != cluster.borrowCaps[asset]) {
                    setCaps(vault, cluster.supplyCaps[asset], cluster.borrowCaps[asset]);
                }
            }

            if (IEVault(vault).interestRateModel() != cluster.irms[i]) {
                setInterestRateModel(vault, cluster.irms[i]);
            }

            setLTVs(vault, cluster.vaults, getLTVs(cluster.ltvs, i));
            setLTVs(vault, cluster.externalVaults, getLTVs(cluster.externalLTVs, i));

            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            if (
                (
                    cluster.hookTargetOverride[asset] != address(uint160(type(uint160).max))
                        && hookTarget != cluster.hookTargetOverride[asset]
                )
                    || (
                        cluster.hookedOpsOverride[asset] != type(uint32).max
                            && hookedOps != cluster.hookedOpsOverride[asset]
                    )
            ) {
                setHookConfig(
                    vault,
                    cluster.hookTargetOverride[asset] != address(uint160(type(uint160).max))
                        && hookTarget != cluster.hookTargetOverride[asset] ? cluster.hookTargetOverride[asset] : hookTarget,
                    cluster.hookedOpsOverride[asset] != type(uint32).max
                        && hookedOps != cluster.hookedOpsOverride[asset] ? cluster.hookedOpsOverride[asset] : hookedOps
                );
            } else if (hookTarget != cluster.hookTarget || hookedOps != cluster.hookedOps) {
                setHookConfig(vault, cluster.hookTarget, cluster.hookedOps);
            }

            if (IEVault(vault).governorAdmin() != cluster.vaultsGovernor) {
                setGovernorAdmin(vault, cluster.vaultsGovernor);
            }
        }

        // transfer the oracle router governance
        for (uint256 i = 0; i < cluster.oracleRouters.length; ++i) {
            address oracleRouter = cluster.oracleRouters[i];
            if (
                !pendingGovernanceTransfer[oracleRouter]
                    && EulerRouter(oracleRouter).governor() != cluster.oracleRoutersGovernor
            ) {
                transferGovernance(oracleRouter, cluster.oracleRoutersGovernor);
                pendingGovernanceTransfer[oracleRouter] = true;
            }
        }

        executeBatch();
    }

    function simulatePendingTransactions() internal virtual {
        if (!isBatchViaSafe()) return;

        SafeTransaction safeUtil = new SafeTransaction();
        SafeTransaction.Transaction[] memory transactions = safeUtil.getPendingTransactions(getSafe());

        for (uint256 i = 0; i < transactions.length; ++i) {
            try safeUtil.simulate(
                transactions[i].operation == SafeUtil.Operation.CALL,
                transactions[i].safe,
                transactions[i].to,
                transactions[i].value,
                transactions[i].data
            ) {} catch {}
        }
    }

    function configureCluster() internal virtual;
    function preOperations() internal virtual {}
    function postOperations() internal virtual {}

    function computeRouterConfiguration(address base, address quote, string memory provider)
        private
        view
        returns (address, address, bool)
    {
        address adapter = getValidAdapter(base, quote, provider);
        bool useStub = false;

        if (_strEq("ExternalVault|", _substring(provider, 0, bytes("ExternalVault|").length))) {
            base = IEVault(base).asset();
        }

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
                if (_strEq(name, "PythOracle") || _strEq(name, "RedstoneCoreOracle") || _strEq(name, "CrossAdapter")) {
                    useStub = true;
                }
            }
        }

        return (base, adapter, useStub);
    }

    // sets LTVs for all passed collaterals of the vault
    function setLTVs(address vault, address[] memory collaterals, uint16[] memory ltvs) private {
        for (uint256 i = 0; i < collaterals.length; ++i) {
            address collateral = collaterals[i];
            address collateralAsset = IEVault(collateral).asset();
            address oracleRouter = IEVault(vault).oracle();
            address unitOfAccount = IEVault(vault).unitOfAccount();
            (address base, address adapter, bool useStub) =
                computeRouterConfiguration(collateralAsset, unitOfAccount, cluster.oracleProviders[collateralAsset]);
            uint16 liquidationLTV = ltvs[i];
            uint16 borrowLTV = liquidationLTV > cluster.spreadLTV ? liquidationLTV - cluster.spreadLTV : 0;
            (uint16 currentBorrowLTV, uint16 targetLiquidationLTV,,,) = IEVault(vault).LTVFull(collateral);

            // configure the oracle router for the collateral before setting the LTV. recognize potentially pending
            // transactions by looking up pendingResolvedVaults and pendingConfiguredAdapters mappings

            // resolve the collateral vault in the router to be able to convert shares to assets
            if (
                !pendingResolvedVaults[oracleRouter][collateral][collateralAsset]
                    && EulerRouter(oracleRouter).resolvedVaults(collateral) != collateralAsset
            ) {
                govSetResolvedVault(oracleRouter, collateral, true);
                pendingResolvedVaults[oracleRouter][collateral][collateralAsset] = true;
            }

            // in case the collateral vault asset is a valid external vault, resolve it in the router
            if (
                collateralAsset != base && !pendingResolvedVaults[oracleRouter][collateralAsset][base]
                    && EulerRouter(oracleRouter).resolvedVaults(collateralAsset) != base
            ) {
                govSetResolvedVault(oracleRouter, collateralAsset, true);
                pendingResolvedVaults[oracleRouter][collateralAsset][base] = true;
            }

            // configure the oracle for the collateral vault asset or the asset of the collateral vault asset
            if (
                !pendingConfiguredAdapters[oracleRouter][base][unitOfAccount]
                    && EulerRouter(oracleRouter).getConfiguredOracle(base, unitOfAccount) != adapter
            ) {
                govSetConfig(oracleRouter, base, unitOfAccount, adapter);
                pendingConfiguredAdapters[oracleRouter][base][unitOfAccount] = true;
            }

            // disregard the current liquidation LTV if currently ramping down, only compare target LTVs to figure out
            // if setting the LTV is required
            if (currentBorrowLTV != borrowLTV || targetLiquidationLTV != liquidationLTV) {
                // in case the stub oracle has to be used, append the following batch critical section:
                // configure the stub oracle, set LTV, configure the desired oracle
                if (useStub && currentBorrowLTV == 0) {
                    govSetConfig_critical(oracleRouter, base, unitOfAccount, cluster.stubOracle);

                    setLTV_critical(
                        vault,
                        collateral,
                        borrowLTV,
                        liquidationLTV,
                        liquidationLTV >= targetLiquidationLTV ? 0 : cluster.rampDuration
                    );

                    govSetConfig_critical(oracleRouter, base, unitOfAccount, adapter);

                    appendCriticalSectionToBatch();
                } else {
                    setLTV(
                        vault,
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
        require(ltvs.length == 0 || ltvs[0].length > vaultIndex, "Invalid vault index");

        uint16[] memory vaultLTVs = new uint16[](ltvs.length);
        for (uint256 i = 0; i < ltvs.length; ++i) {
            vaultLTVs[i] = ltvs[i][vaultIndex];
        }
        return vaultLTVs;
    }

    function dumpCluster() private {
        string memory result = "";
        result = vm.serializeAddress("cluster", "oracleRouters", cluster.oracleRouters);
        result = vm.serializeAddress("cluster", "vaults", cluster.vaults);
        result = vm.serializeAddress("cluster", "irms", cluster.irms);
        result = vm.serializeAddress("cluster", "externalVaults", cluster.externalVaults);
        result = vm.serializeAddress("cluster", "stubOracle", cluster.stubOracle);

        vm.writeJson(result, string.concat(vm.projectRoot(), "/script/Cluster.json"));

        if (isBroadcast()) {
            if (!_strEq(cluster.clusterAddressesPath, "")) vm.writeJson(result, cluster.clusterAddressesPath);
        }
    }

    function loadCluster() private {
        if (!_strEq(cluster.clusterAddressesPath, "")) {
            cluster.clusterAddressesPath = string.concat(vm.projectRoot(), cluster.clusterAddressesPath);

            if (vm.exists(cluster.clusterAddressesPath)) {
                string memory json = vm.readFile(cluster.clusterAddressesPath);
                cluster.oracleRouters = getAddressesFromJson(json, ".oracleRouters");
                cluster.vaults = getAddressesFromJson(json, ".vaults");
                cluster.irms = getAddressesFromJson(json, ".irms");
                cluster.externalVaults = getAddressesFromJson(json, ".externalVaults");
                cluster.stubOracle = getAddressFromJson(json, ".stubOracle");
            }
        }

        for (uint256 i = 0; i < cluster.irms.length; ++i) {
            InterestRateModelDetailedInfo memory irmInfo =
                IRMLens(lensAddresses.irmLens).getInterestRateModelInfo(cluster.irms[i]);

            if (irmInfo.interestRateModelType == InterestRateModelType.KINK) {
                KinkIRMInfo memory kinkIRMInfo = abi.decode(irmInfo.interestRateModelParams, (KinkIRMInfo));
                cluster.kinkIRMMap[kinkIRMInfo.baseRate][kinkIRMInfo.slope1][kinkIRMInfo.slope2][kinkIRMInfo.kink] =
                    cluster.irms[i];
            }
        }

        if (cluster.vaults.length == 0) {
            cluster.vaults = new address[](cluster.assets.length);
        }

        if (cluster.oracleRouters.length == 0) {
            cluster.oracleRouters = new address[](cluster.assets.length);
        }

        if (cluster.irms.length == 0) {
            cluster.irms = new address[](cluster.assets.length);
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
    }

    function checkClusterDataSanity() private view {
        require(cluster.vaults.length == cluster.assets.length, "Vaults and assets length mismatch");
        require(cluster.oracleRouters.length == cluster.assets.length, "OracleRouters and assets length mismatch");
        require(cluster.irms.length == cluster.assets.length, "IRMs and assets length mismatch");
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

        require(bytes(cluster.clusterAddressesPath).length != 0, "Invalid cluster addresses path");
        require(
            cluster.forceZeroGovernors
                || (cluster.oracleRoutersGovernor != address(0) && cluster.vaultsGovernor != address(0)),
            "Invalid governors"
        );
        require(cluster.unitOfAccount != address(0), "Invalid unit of account");
        require(cluster.maxLiquidationDiscount != 0, "Invalid max liquidation discount");
    }
}
