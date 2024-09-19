// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, IEVault} from "../../utils/ScriptUtils.s.sol";
import {OracleVerifier} from "../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../utils/PerspectiveCheck.s.sol";
import {KinkIRM} from "../../04_IRM.s.sol";
import {EVaultDeployer, OracleRouterDeployer} from "../../07_EVault.s.sol";

/*
to run:
   1. curl -L https://foundry.paradigm.xyz | bash
   2. foundryup
   3. git clone https://github.com/euler-xyz/evk-periphery.git && cd evk-periphery
   4. git clone https://github.com/euler-xyz/euler-interfaces.git
   5. git checkout custom-deployment-1 && cp .env.example .env
   6. sed -i '' 's|^ADDRESSES_DIR_PATH=.*|ADDRESSES_DIR_PATH="euler-interfaces/addresses/1"|' ./.env
   7. add the DEPLOYMENT_RPC_URL and the DEPLOYER_KEY in the .env file
   8. forge install && forge compile
   9. ./script/production/ExecuteSolidityScript.sh script/production/mainnet_custom_1/DeployBTCVaults.s.sol
*/

contract DeployBTCVaults is BatchBuilder {
    // final governor addresses
    address internal constant MULTISIG = 0x38afC3aA2c76b4cA1F8e1DabA68e998e1F4782DB;
    address internal constant ORACLE_ROUTER_GOVERNOR = MULTISIG;
    address internal constant VAULTS_GOVERNOR = MULTISIG;
    address internal constant BORROWABLE_VAULTS_FEE_RECEIVER = MULTISIG;

    // assets
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;

    // oracle adapters
    address internal constant WBTCBTC = 0xc38B1ae5f9bDd68D44b354fD06b16488Be4Bc0d4;
    address internal constant CBBTCBTC = 0x14C855046e91E91033Aaff3191EA6717Fb759A05;
    address internal constant LBTCBTC = 0x8a14C0190385cA8D9Ac7a134af39f7EBb13D5782;

    mapping(address => address) internal vaults;

    address internal oracleRouter;
    address[] internal assets;
    address[] internal oracleAdapters;
    uint16[] internal supplyCaps;
    uint16[] internal borrowCaps;
    uint16[] internal maxLiquidationDiscounts;
    uint16[] internal interestFees;
    address[] internal interestRateModels;
    uint16[][] internal LTVs;

    constructor() {
        assets         = [WBTC,    CBBTC,    LBTC];
        oracleAdapters = [WBTCBTC, CBBTCBTC, LBTCBTC];
        supplyCaps     = [0,       0,        0]; // fixme
        borrowCaps     = [0,       0,        0]; // fixme
        supplyCaps     = encodeAmountCaps(assets, supplyCaps); // fixme
        borrowCaps     = encodeAmountCaps(assets, borrowCaps); // fixme

        //                          WBTC     CBBTC     LBTC
        maxLiquidationDiscounts =  [0.150e4, 0.150e4, 0.150e4];
        interestFees            =  [0.100e4, 0.100e4, 0.100e4];
        
        LTVs                    = [[0.000e4, 0.945e4, 0.945e4],  // WBTC
                                   [0.945e4, 0.000e4, 0.945e4],  // CBBTC
                                   [0.945e4, 0.945e4, 0.000e4]]; // LBTC
    }

    function run() public returns (address[] memory) {
        // deploy the IRM
        {
            KinkIRM deployer = new KinkIRM();

            // fixme
            // Base=0% APY  Kink(90%)=2% APY  Max=8% APY
            address IRM = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 162339942, 4217210302, 3865470566);

            //                    WBTC  CBBTC  LBTC
            interestRateModels = [IRM,  IRM,   IRM];
        }

        // deploy the oracle router
        {
            OracleRouterDeployer deployer = new OracleRouterDeployer();
            oracleRouter = deployer.deploy(peripheryAddresses.oracleRouterFactory);
        }

        // deploy the vaults
        {
            EVaultDeployer deployer = new EVaultDeployer();
            for (uint256 i = 0; i < assets.length; ++i) {
                address asset = assets[i];
                vaults[asset] = deployer.deploy(coreAddresses.eVaultFactory, true, asset, oracleRouter, BTC);
            }
        }

        // configure the oracle router
        for (uint256 i = 0; i < assets.length; ++i) {
            address asset = assets[i];
            govSetResolvedVault(oracleRouter, vaults[asset], true);
            govSetConfig(oracleRouter, asset, BTC, oracleAdapters[i]);
        }
        transferGovernance(oracleRouter, ORACLE_ROUTER_GOVERNOR);

        // configure the vaults
        for (uint256 i = 0; i < assets.length; ++i) {
            address vault = vaults[assets[i]];
            setMaxLiquidationDiscount(vault, maxLiquidationDiscounts[i]);
            setLiquidationCoolOffTime(vault, 1);
            setInterestRateModel(vault, interestRateModels[i]);
            setInterestFee(vault, interestFees[i]);
            setFeeReceiver(vault, BORROWABLE_VAULTS_FEE_RECEIVER);
            setCaps(vault, supplyCaps[i], borrowCaps[i]);

            for (uint256 j = 0; j < assets.length; ++j) {
                address collateral = vaults[assets[j]];
                uint16 ltv = LTVs[j][i];

                if (ltv != 0) setLTV(vault, collateral, ltv - 0.025e4, ltv, 0);
            }

            setHookConfig(vault, address(0), 0);
            setGovernorAdmin(vault, VAULTS_GOVERNOR);
        }
        
        executeBatch();

        // sanity check the oracle config and perspectives
        address[] memory results = new address[](assets.length);
        for (uint256 i = 0; i < assets.length; ++i) {
            address vault = vaults[assets[i]];

            OracleVerifier.verifyOracleConfig(vault);
            
            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngoverned0xPerspective,
                vault,
                PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR | PerspectiveVerifier.E__LTV_COLLATERAL_RECOGNITION
            );
            
            results[i] = vault;
        }

        return results;
    }
}
