// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "../../lib/euler-earn/lib/erc4626-tests/ERC4626.test.sol";

import {MockToken} from "../FeeFlow/lib/MockToken.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {ERC4626EVCCollateralFreezableHarness} from "./lib/VaultHarnesses.sol";

contract ERC4626EVCCollateralFreezableStdTest is EVaultTestBase, ERC4626Test {
    function setUp() public override (EVaultTestBase, ERC4626Test) {
        super.setUp();

        _underlying_ = address(new MockToken("Mock ERC20", "MERC20"));
        _vault_ = address(
            new ERC4626EVCCollateralFreezableHarness(
                admin, address(evc), address(permit2), _underlying_, "EVC Collateral", "EVCC"
            )
        );
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = true;
    }

    function test_deposit(Init memory init, uint256 assets, uint256 allowance) public virtual override {
        // max uint is special cased
        assets = bound(assets, 0, type(uint256).max - 1);
        super.test_deposit(init, assets, allowance);
    }

    function test_previewDeposit(Init memory init, uint256 assets) public virtual override {
        // max uint is special cased
        assets = bound(assets, 0, type(uint256).max - 1);
        super.test_previewDeposit(init, assets);
    }

    function test_redeem(Init memory init, uint256 shares, uint256 allowance) public virtual override {
        // max uint is special cased
        shares = bound(shares, 0, type(uint256).max - 1);
        super.test_redeem(init, shares, allowance);
    }

    function test_previewRedeem(Init memory init, uint256 shares) public virtual override {
        // max uint is special cased
        shares = bound(shares, 0, type(uint256).max - 1);
        super.test_previewRedeem(init, shares);
    }
}
