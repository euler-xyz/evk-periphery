// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder} from "../../utils/ScriptUtils.s.sol";
import {IRMLens} from "../../../src/Lens/IRMLens.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {KinkIRM} from "../../04_IRM.s.sol";
import {EVaultDeployer, OracleRouterDeployer, EulerRouter} from "../../07_EVault.s.sol";
import {OracleLens} from "../../../src/Lens/OracleLens.sol";
import {StubOracle} from "../../utils/ScriptUtils.s.sol";
import "../../../src/Lens/LensTypes.sol";

abstract contract Addresses {
    address internal constant EULER_DEPLOYER = 0xEe009FAF00CF54C1B4387829aF7A8Dc5f0c8C8C5;
    address internal constant EULER_DAO_MULTISIG = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;

    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant cbETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address internal constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant ezETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address internal constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address internal constant METH = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;
    address internal constant RSETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address internal constant sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address internal constant ETHx = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    address internal constant rswETH = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant PYUSD = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8;
    address internal constant USDY = 0x96F6eF951840721AdBF46Ac996b59E0235CB985C;
    address internal constant wM = 0x437cc33344a0B27A429f795ff6B469C72698B291;
    address internal constant mTBILL = 0xDD629E5241CbC5919847783e6C96B2De4754e438;
    address internal constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address internal constant wUSDM = 0x57F5E098CaD7A3D1Eed53991D4d66C45C9AF7812;
    address internal constant EURC = 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c;
    address internal constant sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address internal constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address internal constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant stUSD = 0x0022228a2cc5E7eF0274A7Baa600d44da5aB5776;
    address internal constant stEUR = 0x004626A008B1aCdC4c74ab51644093b155e59A23;
    address internal constant FDUSD = 0xc5f0f7b66764F6ec8C8Dff7BA683102295E16409;
    address internal constant USD0 = 0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5;
    address internal constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address internal constant crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address internal constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address internal constant tBTC = 0x18084fbA666a33d37592fA2633fD49a74DD93a88;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address internal constant eBTC = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address internal constant SOLVBTC = 0x7A56E1C57C7475CCf742a1832B028F0456652F97;
}

abstract contract MaintainCluster is BatchBuilder, Addresses {
    struct OracleOverride {
        address router;
        address adapter;
        address base;
        address quote;
    }

    struct Cluster {
        string clusterAddressesPath;
        address oracleRoutersGovernor;
        address vaultsGovernor;
        address[] assets;
        address[] vaults;
        address[] oracleRouters;
        uint16[][] ltvs;
        address[] auxiliaryVaults;
        uint16[][] auxiliaryLTVs;
        address unitOfAccount;
        address feeReceiver;
        uint16 interestFee;
        uint16 maxLiquidationDiscount;
        uint16 liquidationCoolOffTime;
        address hookTarget;
        uint32 hookedOps;
        uint32 configFlags;
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
        OracleOverride[] stubOracleOverrides;
    }

    Cluster internal cluster;
    mapping(address router => mapping(address vault => bool resolved)) internal resolvedVaults;
    mapping(address router => mapping(address base => mapping(address quote => bool set))) internal configuredAdapters;

    modifier initialize() {
        configureCluster();
        encodeAmountCaps(cluster.assets, cluster.supplyCaps);
        encodeAmountCaps(cluster.assets, cluster.borrowCaps);

        loadCluster();

        _;

        dumpCluster();
        verifyCluster();
    }

    function run() public initialize {
        // deploy the stub oracle (needed in case pull oracle is meant to be used for a collateral asset and its stale)
        if (cluster.stubOracle == address(0)) {
            startBroadcast();
            cluster.stubOracle = address(new StubOracle());
            stopBroadcast();
        }

        // deploy the oracle routers
        {
            OracleRouterDeployer deployer = new OracleRouterDeployer();
            address oracleRouter;
            for (uint256 i = 0; i < cluster.assets.length; ++i) {
                if (cluster.oracleRouters[i] == address(0)) {
                    if (oracleRouter == address(0)) {
                        oracleRouter = deployer.deploy(peripheryAddresses.oracleRouterFactory);

                        if (isBatchViaSafe()) {
                            addBatchItem(
                                oracleRouter,
                                getDeployer(),
                                0,
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
                if (cluster.vaults[i] == address(0)) {
                    cluster.vaults[i] = deployer.deploy(
                        coreAddresses.eVaultFactory,
                        true,
                        cluster.assets[i],
                        cluster.oracleRouters[i],
                        cluster.unitOfAccount
                    );

                    if (isBatchViaSafe()) {
                        addBatchItem(
                            cluster.vaults[i],
                            getDeployer(),
                            0,
                            abi.encodeCall(IEVault(cluster.vaults[i]).setGovernorAdmin, (getSafe()))
                        );
                    }
                }
            }
        }

        executeBatchDirectly();

        // deploy the IRMs
        {
            KinkIRM deployer = new KinkIRM();
            for (uint256 i = 0; i < cluster.assets.length; ++i) {
                uint256[4] storage p = cluster.kinkIRMParams[cluster.assets[i]];
                address irm = cluster.kinkIRMMap[p[0]][p[1]][p[2]][p[3]];

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

            {
                address oracleRouter = cluster.oracleRouters[i];
                address unitOfAccount = IEVault(vault).unitOfAccount();
                (address adapter, bool useStub) = getAdapterToSet(asset, unitOfAccount, cluster.oracleProviders[asset]);

                if (
                    !configuredAdapters[oracleRouter][asset][unitOfAccount]
                        && EulerRouter(oracleRouter).getConfiguredOracle(asset, unitOfAccount) != adapter
                ) {
                    if (useStub) {
                        cluster.stubOracleOverrides.push(
                            OracleOverride({router: oracleRouter, adapter: adapter, base: asset, quote: unitOfAccount})
                        );
                        adapter = cluster.stubOracle;
                    }

                    govSetConfig(oracleRouter, asset, unitOfAccount, adapter);
                    configuredAdapters[oracleRouter][asset][unitOfAccount] = true;
                }
            }

            {
                address feeReceiver = IEVault(vault).feeReceiver();
                if (feeReceiver != cluster.feeReceiver) {
                    setFeeReceiver(vault, cluster.feeReceiver);
                } else if (
                    cluster.feeReceiverOverride[asset] != address(0)
                        && feeReceiver != cluster.feeReceiverOverride[asset]
                ) {
                    setFeeReceiver(vault, cluster.feeReceiverOverride[asset]);
                }
            }

            {
                uint16 interestFee = IEVault(vault).interestFee();
                if (interestFee != cluster.interestFee) {
                    setInterestFee(vault, cluster.interestFee);
                } else if (cluster.interestFeeOverride[asset] != 0 && interestFee != cluster.interestFeeOverride[asset])
                {
                    setInterestFee(vault, cluster.interestFeeOverride[asset]);
                }
            }

            {
                uint16 maxLiquidationDiscount = IEVault(vault).maxLiquidationDiscount();
                if (maxLiquidationDiscount != cluster.maxLiquidationDiscount) {
                    setMaxLiquidationDiscount(vault, cluster.maxLiquidationDiscount);
                } else if (
                    cluster.maxLiquidationDiscountOverride[asset] != 0
                        && maxLiquidationDiscount != cluster.maxLiquidationDiscountOverride[asset]
                ) {
                    setMaxLiquidationDiscount(vault, cluster.maxLiquidationDiscountOverride[asset]);
                }
            }

            {
                uint16 liquidationCoolOffTime = IEVault(vault).liquidationCoolOffTime();
                if (liquidationCoolOffTime != cluster.liquidationCoolOffTime) {
                    setLiquidationCoolOffTime(vault, cluster.liquidationCoolOffTime);
                } else if (
                    cluster.liquidationCoolOffTimeOverride[asset] != 0
                        && liquidationCoolOffTime != cluster.liquidationCoolOffTimeOverride[asset]
                ) {
                    setLiquidationCoolOffTime(vault, cluster.liquidationCoolOffTimeOverride[asset]);
                }
            }

            {
                uint32 configFlags = IEVault(vault).configFlags();
                if (configFlags != cluster.configFlags) {
                    setConfigFlags(vault, cluster.configFlags);
                } else if (cluster.configFlagsOverride[asset] != 0 && configFlags != cluster.configFlagsOverride[asset])
                {
                    setConfigFlags(vault, cluster.configFlagsOverride[asset]);
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
            setLTVs(vault, cluster.auxiliaryVaults, getLTVs(cluster.auxiliaryLTVs, i));
        }

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            address vault = cluster.vaults[i];
            address asset = IEVault(vault).asset();

            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            if (hookTarget != cluster.hookTarget || hookedOps != cluster.hookedOps) {
                setHookConfig(vault, cluster.hookTarget, cluster.hookedOps);
            } else if (
                (cluster.hookTargetOverride[asset] != address(0) && hookTarget != cluster.hookTargetOverride[asset])
                    || (cluster.hookedOpsOverride[asset] != 0 && hookedOps != cluster.hookedOpsOverride[asset])
            ) {
                setHookConfig(
                    vault,
                    cluster.hookTargetOverride[asset] != address(0) && hookTarget != cluster.hookTargetOverride[asset]
                        ? cluster.hookTargetOverride[asset]
                        : hookTarget,
                    cluster.hookedOpsOverride[asset] != 0 && hookedOps != cluster.hookedOpsOverride[asset]
                        ? cluster.hookedOpsOverride[asset]
                        : hookedOps
                );
            }

            if (IEVault(vault).governorAdmin() != cluster.vaultsGovernor) {
                setGovernorAdmin(vault, cluster.vaultsGovernor);
            }
        }

        // apply oracle overrides and transfer the oracle router governance
        for (uint256 i = 0; i < cluster.stubOracleOverrides.length; ++i) {
            OracleOverride storage o = cluster.stubOracleOverrides[i];
            govSetConfig(o.router, o.base, o.quote, o.adapter);
        }

        for (uint256 i = 0; i < cluster.oracleRouters.length; ++i) {
            address oracleRouter = cluster.oracleRouters[i];
            if (EulerRouter(oracleRouter).governor() != cluster.oracleRoutersGovernor) {
                transferGovernance(oracleRouter, cluster.oracleRoutersGovernor);
            }
        }

        executeBatch();
    }

    function configureCluster() internal virtual;
    function verifyCluster() internal virtual;

    function getAdapterToSet(address base, address quote, string memory provider)
        private
        view
        returns (address adapter, bool useStub)
    {
        adapter = getValidAdapter(base, quote, provider);

        (bool success, bytes memory result) = adapter.staticcall(abi.encodeCall(EulerRouter.getQuote, (0, base, quote)));

        useStub =
            (!success || result.length < 32) && OracleLens(lensAddresses.oracleLens).isStalePullOracle(adapter, result);

        if (useStub) return (adapter, useStub);

        (success, result) = adapter.staticcall(abi.encodeCall(EulerRouter(adapter).name, ()));

        if (success && result.length >= 32) {
            string memory name = abi.decode(result, (string));
            if (_strEq(name, "PythOracle") || _strEq(name, "RedstoneCoreOracle")) {
                useStub = true;
            }
        }

        return (adapter, useStub);
    }

    function setLTVs(address vault, address[] memory collaterals, uint16[] memory ltvs) private {
        for (uint256 i = 0; i < collaterals.length; ++i) {
            address collateral = collaterals[i];
            address collateralAsset = IEVault(collateral).asset();
            uint16 liquidationLTV = ltvs[i];
            uint16 borrowLTV = liquidationLTV > 0.02e4 ? liquidationLTV - 0.02e4 : 0;
            (uint16 currentBorrowLTV, uint16 targetLiquidationLTV,,,) = IEVault(vault).LTVFull(collateral);

            if (currentBorrowLTV != borrowLTV || targetLiquidationLTV != liquidationLTV) {
                address oracleRouter = IEVault(vault).oracle();
                address unitOfAccount = IEVault(vault).unitOfAccount();
                (address adapter, bool useStub) =
                    getAdapterToSet(collateralAsset, unitOfAccount, cluster.oracleProviders[collateralAsset]);

                // configure the oracle router before setting the LTVs
                if (
                    !resolvedVaults[oracleRouter][collateral]
                        && EulerRouter(oracleRouter).resolvedVaults(collateral) == address(0)
                ) {
                    govSetResolvedVault(oracleRouter, collateral, true);
                    resolvedVaults[oracleRouter][collateral] = true;
                }

                if (
                    !configuredAdapters[oracleRouter][collateralAsset][unitOfAccount]
                        && EulerRouter(oracleRouter).getConfiguredOracle(collateralAsset, unitOfAccount) != adapter
                ) {
                    if (useStub) {
                        cluster.stubOracleOverrides.push(
                            OracleOverride({
                                router: oracleRouter,
                                adapter: adapter,
                                base: collateralAsset,
                                quote: unitOfAccount
                            })
                        );
                        adapter = cluster.stubOracle;
                    }

                    govSetConfig(oracleRouter, collateralAsset, unitOfAccount, adapter);
                    configuredAdapters[oracleRouter][collateralAsset][unitOfAccount] = true;
                }

                setLTV(
                    vault, collateral, borrowLTV, liquidationLTV, liquidationLTV >= targetLiquidationLTV ? 0 : 1 days
                );
            }
        }
    }

    function getLTVs(uint16[][] memory ltvs, uint256 vaultIndex) private pure returns (uint16[] memory) {
        require(ltvs.length == 0 || ltvs[0].length > vaultIndex, "Invalid vault index");

        uint16[] memory vaultLTVs = new uint16[](ltvs.length);
        for (uint256 i = 0; i < ltvs.length; ++i) {
            vaultLTVs[i] = ltvs[i][vaultIndex];
        }
        return vaultLTVs;
    }

    function dumpCluster() private {
        if (!isBroadcast()) return;

        string memory result = "";
        result = vm.serializeAddress("cluster", "oracleRouters", cluster.oracleRouters);
        result = vm.serializeAddress("cluster", "vaults", cluster.vaults);
        result = vm.serializeAddress("cluster", "irms", cluster.irms);
        result = vm.serializeAddress("cluster", "auxiliaryVaults", cluster.auxiliaryVaults);
        result = vm.serializeAddress("cluster", "stubOracle", cluster.stubOracle);

        if (!_strEq(cluster.clusterAddressesPath, "")) vm.writeJson(result, cluster.clusterAddressesPath);
    }

    function loadCluster() private {
        if (!_strEq(cluster.clusterAddressesPath, "")) {
            cluster.clusterAddressesPath = string.concat(vm.projectRoot(), cluster.clusterAddressesPath);

            if (vm.exists(cluster.clusterAddressesPath)) {
                string memory json = vm.readFile(cluster.clusterAddressesPath);
                cluster.oracleRouters = getAddressesFromJson(json, ".oracleRouters");
                cluster.vaults = getAddressesFromJson(json, ".vaults");
                cluster.irms = getAddressesFromJson(json, ".irms");
                cluster.auxiliaryVaults = getAddressesFromJson(json, ".auxiliaryVaults");
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

        checkDataSanity();
    }

    function checkDataSanity() private view {
        require(cluster.vaults.length == cluster.assets.length, "Vaults and assets length mismatch");
        require(cluster.oracleRouters.length == cluster.assets.length, "OracleRouters and assets length mismatch");
        require(cluster.irms.length == cluster.assets.length, "IRMs and assets length mismatch");
        require(cluster.ltvs.length == cluster.assets.length, "LTVs and assets length mismatch");
        require(
            cluster.auxiliaryLTVs.length == cluster.auxiliaryVaults.length,
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

        for (uint256 i = 0; i < cluster.auxiliaryVaults.length; ++i) {
            require(cluster.auxiliaryVaults[i] != address(0), "Auxiliary vault cannot be zero address");
        }

        for (uint256 i = 0; i < cluster.ltvs.length; ++i) {
            require(cluster.ltvs[i].length == cluster.assets.length, "LTVs and assets length mismatch");
        }

        for (uint256 i = 0; i < cluster.auxiliaryLTVs.length; ++i) {
            require(
                cluster.auxiliaryLTVs[i].length == cluster.assets.length, "Auxiliary LTVs and assets length mismatch"
            );
        }
    }
}
