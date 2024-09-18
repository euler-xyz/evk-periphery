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
    address internal constant LBTCBTC = address(0); // fixme

    mapping(address => address) internal escrowVaults;
    mapping(address => address) internal borrowableVaults;

    address internal oracleRouter;
    address[] internal assets;
    address[] internal oracleAdapters;
    uint16[] internal escrowSupplyCaps; // fixme
    uint16[] internal borrowableMaxLiquidationDiscounts;
    uint16[] internal borrowableInterestFees;
    address[] internal borrowableInterestRateModels;
    uint16[][] internal borrowableEscrowLTVs;

    constructor() {
        assets           = [WBTC,    CBBTC,    LBTC];
        oracleAdapters   = [WBTCBTC, CBBTCBTC, LBTCBTC];
        escrowSupplyCaps = [0,       0,        0]; // fixme
        escrowSupplyCaps = encodeAmountCaps(assets, escrowSupplyCaps); // fixme

        //                                    WBTC      CBBTC
        borrowableMaxLiquidationDiscounts =  [0.15e4,   0.15e4];
        borrowableInterestFees            =  [0.10e4,   0.10e4];
        borrowableEscrowLTVs  /* WBTC  */ = [[0.000e4, 0.000e4],
                              /* CBBTC */    [0.000e4, 0.000e4],
                              /* LBTC  */    [0.945e4, 0.945e4]];
    }

    function run() public returns (address[] memory) {
        // deploy the IRM
        {
            KinkIRM deployer = new KinkIRM();

            // fixme
            // Base=0% APY  Kink(90%)=2% APY  Max=?% APY
            address IRM = deployer.deploy(peripheryAddresses.kinkIRMFactory, );

            //                              WBTC  CBBTC
            borrowableInterestRateModels = [IRM,  IRM];
        }

        // deploy the oracle router
        {
            OracleRouterDeployer deployer = new OracleRouterDeployer();
            oracleRouter = deployer.deploy(peripheryAddresses.oracleRouterFactory);
        }

        // deploy the vaults
        {
            EVaultDeployer deployer = new EVaultDeployer();
            escrowVaults[LBTC] = deployer.deploy(coreAddresses.eVaultFactory, true, asset);
            borrowableVaults[WBTC] = deployer.deploy(coreAddresses.eVaultFactory, true, WBTC, oracleRouter, BTC);
            borrowableVaults[CBBTC] = deployer.deploy(coreAddresses.eVaultFactory, true, CBBTC, oracleRouter, BTC);
        }

        // configure the oracle router
        govSetResolvedVault(oracleRouter, escrowVaults[LBTC], true);
        govSetResolvedVault(oracleRouter, borrowableVaults[WBTC], true);
        govSetResolvedVault(oracleRouter, borrowableVaults[CBBTC], true);

        for (uint256 i = 0; i < assets.length; ++i) {
            govSetConfig(oracleRouter, assets[i], BTC, oracleAdapters[i]);
        }
        transferGovernance(oracleRouter, ORACLE_ROUTER_GOVERNOR);

        // configure the LBTC escrow vault retaining the governorship
        {
            address vault = escrowVaults[assets[i]];
            setCaps(vault, escrowSupplyCaps[i], 0); // fixme
            setHookConfig(vault, address(0), 0);
            setGovernorAdmin(vault, VAULTS_GOVERNOR);
        }

        // configure the borrowable vaults
        for (uint256 i = 0; i < 2; ++i) {
            address vault = borrowableVaults[assets[i]];
            setMaxLiquidationDiscount(vault, borrowableMaxLiquidationDiscounts[i]);
            setLiquidationCoolOffTime(vault, 1);
            setInterestRateModel(vault, borrowableInterestRateModels[i]);
            setInterestFee(vault, borrowableInterestFees[i]);
            setFeeReceiver(vault, BORROWABLE_VAULTS_FEE_RECEIVER);

            for (uint256 j = 0; j < assets.length; ++j) {
                address collateral = escrowVaults[assets[j]];
                uint16 ltv = LTVs[j][i];

                if (ltv != 0) setLTV(vault, collateral, ltv - 0.025e4, ltv, 0);
            }

            setHookConfig(vault, address(0), 0);
            setGovernorAdmin(vault, VAULTS_GOVERNOR);
        }
        
        executeBatch();

        // sanity check the oracle config and perspectives
        address[] memory results = new address[](3);
        OracleVerifier.verifyOracleConfig(escrowVaults[LBTC]);
        PerspectiveVerifier.verifyPerspective(
            peripheryAddresses.escrowedCollateralPerspective,
            escrowVaults[LBTC],
            PerspectiveVerifier.E__GOVERNOR
        );
        results[i] = escrowVaults[LBTC];

        for (uint256 i = 0; i < 2; ++i) {
            address vault = borrowableVaults[assets[i]];
            
            OracleVerifier.verifyOracleConfig(vault);
            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngoverned0xPerspective,
                vault,
                PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR | PerspectiveVerifier.E__LTV_COLLATERAL_RECOGNITION
            );
            results[i + 1] = vault;
        }

        return results;
    }
}
