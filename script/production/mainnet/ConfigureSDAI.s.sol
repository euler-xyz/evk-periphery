// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "../../utils/ScriptUtils.s.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

contract ConfigureSDAI is ScriptUtils {
    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant sDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address internal constant ORACLE_ROUTER = 0x83B3b76873D36A28440cF53371dF404c42497136;
    address internal constant DAIUSD = address(0); // TODO

    address internal constant DAO_MULTISIG = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;
    address internal constant ORACLE_ROUTER_GOVERNOR = DAO_MULTISIG;
    address internal constant RISK_OFF_VAULTS_GOVERNOR = DAO_MULTISIG;

    address internal constant escrowVaultSDAI = address(0); // TODO
    mapping(address => address) internal riskOffVaults;

    constructor() {
        riskOffVaults[WETH] = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2;
        riskOffVaults[wstETH] = 0xbC4B4AC47582c3E38Ce5940B80Da65401F4628f1;
        riskOffVaults[USDC] = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
        riskOffVaults[USDT] = 0x313603FA690301b0CaeEf8069c065862f9162162;
    }

    function run() public view returns (bytes memory) {
        // configure the oracle router
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](7);
        items[0].targetContract = ORACLE_ROUTER;
        items[0].onBehalfOfAccount = ORACLE_ROUTER_GOVERNOR;
        items[0].data = abi.encodeCall(EulerRouter.govSetConfig, (DAI, USD, DAIUSD));

        items[1].targetContract = ORACLE_ROUTER;
        items[1].onBehalfOfAccount = ORACLE_ROUTER_GOVERNOR;
        items[1].data = abi.encodeCall(EulerRouter.govSetResolvedVault, (sDAI, true));

        items[2].targetContract = ORACLE_ROUTER;
        items[2].onBehalfOfAccount = ORACLE_ROUTER_GOVERNOR;
        items[2].data = abi.encodeCall(EulerRouter.govSetResolvedVault, (escrowVaultSDAI, true));

        // configure the LTVs
        items[3].targetContract = riskOffVaults[WETH];
        items[3].onBehalfOfAccount = RISK_OFF_VAULTS_GOVERNOR;
        items[3].data = abi.encodeCall(IEVault(riskOffVaults[WETH]).setLTV, (escrowVaultSDAI, 0.74e4, 0.76e4, 0));

        items[4].targetContract = riskOffVaults[wstETH];
        items[4].onBehalfOfAccount = RISK_OFF_VAULTS_GOVERNOR;
        items[4].data = abi.encodeCall(IEVault(riskOffVaults[wstETH]).setLTV, (escrowVaultSDAI, 0.74e4, 0.76e4, 0));

        items[5].targetContract = riskOffVaults[USDC];
        items[5].onBehalfOfAccount = RISK_OFF_VAULTS_GOVERNOR;
        items[5].data = abi.encodeCall(IEVault(riskOffVaults[USDC]).setLTV, (escrowVaultSDAI, 0.85e4, 0.87e4, 0));

        items[6].targetContract = riskOffVaults[USDT];
        items[6].onBehalfOfAccount = RISK_OFF_VAULTS_GOVERNOR;
        items[6].data = abi.encodeCall(IEVault(riskOffVaults[USDT]).setLTV, (escrowVaultSDAI, 0.85e4, 0.87e4, 0));

        return abi.encodeCall(IEVC.batch, (items));
    }
}
