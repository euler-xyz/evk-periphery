// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../ManageClusterBase.s.sol";
import {OracleVerifier} from "../../utils/SanityCheckOracle.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal immutable WETH;
    address internal immutable USDC;
    address internal immutable USDT;
    address internal immutable WBTC;
    address internal immutable IRM_ADAPTIVE_USD;
    address internal immutable IRM_ADAPTIVE_USD_YB;
    address internal immutable IRM_ADAPTIVE_ETH;
    address internal immutable IRM_ADAPTIVE_BTC;

    constructor() {
        if (block.chainid == 1) {
            WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
            USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
            WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        } else if (block.chainid == 8453) {
            WETH = 0x4200000000000000000000000000000000000006;
            USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
            USDT = 0x102d758f688a4C1C5a80b116bD945d4455460282;
        } else if (block.chainid == 42161) {
            WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
            USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
            USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        }

        if (block.chainid == 1) {
            IRM_ADAPTIVE_USD = 0x66d56E8Acad6a8fb6914753317cD3277D458E540;
            IRM_ADAPTIVE_USD_YB = 0x2F9E82B49b542736216DA531EBAC2b6B32f43060;
            IRM_ADAPTIVE_ETH = 0xF1a82e49c565511DF5aA36eF2b23ba9e4aF0985B;
            IRM_ADAPTIVE_BTC = 0x6098DEAEB73A1C26626e4a3B87495BD3d6AdA8b3;
        } else if (block.chainid == 8453) {
            IRM_ADAPTIVE_USD = 0x17365A5319BB317490dBb000F8073A845E7a1012;
            IRM_ADAPTIVE_USD_YB = 0x72C9D7c1e9e954c9Dc85E49dB76fF614a335d2a5;
            IRM_ADAPTIVE_ETH = 0xb70de5cEcA993c08BceE4296E3fEbcc9D7C0AdCD;
            IRM_ADAPTIVE_BTC = 0x26472E20e09a01AA50a0F2C4d96E99ac58268a8D;
        } else if (block.chainid == 42161) {
            IRM_ADAPTIVE_USD = 0x2D76638aA2fA9Ce16417485d46Ed8EEDC1Db1AA4;
            IRM_ADAPTIVE_USD_YB = 0x0a473bbcBa1c89ffbD7AfACdD6CBE019Ab5F2dD4;
            IRM_ADAPTIVE_ETH = 0xF583692cCa56b084cb1f9D4C3e3939C43f73409D;
            IRM_ADAPTIVE_BTC = 0xE1f126e815D4BF8CCE2F94552196EcA9a7c1B96c;
        }
    }

    uint16 internal constant LTV_ZERO = 0.0e4;
    uint16 internal constant LTV__LOW = 0.91e4;
    uint16 internal constant LTV_HIGH = 0.95e4;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {
    function configureCluster() internal virtual override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = governorAddresses.accessControlEmergencyGovernor;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the
        // feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;

        // define max liquidation discount here. if needed to be defined per asset, populate the
        // maxLiquidationDiscountOverride mapping
        cluster.maxLiquidationDiscount = 0.15e4;

        // define liquidation cool off time here. if needed to be defined per asset, populate the
        // liquidationCoolOffTimeOverride mapping
        cluster.liquidationCoolOffTime = 1;

        // define hook target and hooked ops here. if needed to be defined per asset, populate the hookTargetOverride
        // and hookedOpsOverride mappings
        cluster.hookTarget = address(0);
        cluster.hookedOps = 0;

        // define config flags here. if needed to be defined per asset, populate the configFlagsOverride mapping
        cluster.configFlags = 0;

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        for (uint256 i = 0; i < cluster.assets.length; ++i) {
            cluster.supplyCaps[cluster.assets[i]] = type(uint256).max;
            cluster.borrowCaps[cluster.assets[i]] = type(uint256).max;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.01e4;

        // not to deploy and use a stub oracle (as we're not expecting to use Pyth oracles)
        setNoStubOracle(true);
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
