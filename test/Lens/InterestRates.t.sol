// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../lib/euler-vault-kit/test/unit/evault/EVaultTestBase.t.sol";
import {IEVault} from "../../lib/euler-vault-kit/src/EVault/IEVault.sol";
import {RPow} from "../../lib/euler-vault-kit/src/EVault/shared/lib/RPow.sol";

import "../../src/Lens/LensTypes.sol";
import {EulerKinkIRMFactory} from "../../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerIRMAdaptiveCurveFactory} from "../../src/IRMFactory/EulerIRMAdaptiveCurveFactory.sol";
import {EulerKinkIRMFactory} from "../../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerIRMAdaptiveCurveFactory} from "../../src/IRMFactory/EulerIRMAdaptiveCurveFactory.sol";
import {AccountLens} from "../../src/Lens/AccountLens.sol";
import {OracleLens} from "../../src/Lens/OracleLens.sol";
import {IRMLens} from "../../src/Lens/IRMLens.sol";
import {UtilsLens} from "../../src/Lens/UtilsLens.sol";
import {VaultLens} from "../../src/Lens/VaultLens.sol";

contract InterestRates is EVaultTestBase {
    uint256 SECONDS_PER_YEAR = 365.2425 days;
    uint256 ONE = 1e27;
    uint256 CONFIG_SCALE = 1e4;

    address user1;
    address user2;
    address user3;

    EulerKinkIRMFactory public irmFactory;
    EulerIRMAdaptiveCurveFactory public irmAdaptiveCurveFactory;
    EulerKinkIRMFactory public irmKinkyFactory;
    EulerIRMAdaptiveCurveFactory public irmFixedCyclicalBinaryFactory;
    AccountLens public accountLens;
    OracleLens public oracleLens;
    IRMLens public irmLens;
    UtilsLens public utilsLens;
    VaultLens public vaultLens;

    function setUp() public override {
        vm.chainId(1);

        super.setUp();

        irmFactory = new EulerKinkIRMFactory();
        irmAdaptiveCurveFactory = new EulerIRMAdaptiveCurveFactory();
        irmKinkyFactory = new EulerKinkIRMFactory();
        irmFixedCyclicalBinaryFactory = new EulerIRMAdaptiveCurveFactory();
        accountLens = new AccountLens();
        oracleLens = new OracleLens(address(0));
        irmLens = new IRMLens(
            address(irmFactory),
            address(irmAdaptiveCurveFactory),
            address(irmKinkyFactory),
            address(irmFixedCyclicalBinaryFactory)
        );
        utilsLens = new UtilsLens(address(factory), address(oracleLens));
        vaultLens = new VaultLens(address(oracleLens), address(utilsLens), address(irmLens));

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        assetTST.mint(user1, 100e18);
        assetTST.mint(user2, 100e18);

        startHoax(user1);
        assetTST.approve(address(eTST), type(uint256).max);
        startHoax(user2);
        assetTST.approve(address(eTST), type(uint256).max);

        assetTST2.mint(user3, 100e18);
        startHoax(user3);
        assetTST2.approve(address(eTST2), type(uint256).max);
        evc.enableCollateral(user3, address(eTST2));
        evc.enableController(user3, address(eTST));
        eTST2.deposit(50e18, user3);

        oracle.setPrice(address(assetTST), unitOfAccount, 0.1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 0.2e18);

        startHoax(address(this));
        eTST.setLTV(address(eTST2), 0.21e4, 0.21e4, 0);

        skip(31 * 60);
    }

    function test_basicInterestLens() public {
        startHoax(user1);
        eTST.deposit(1e18, user1);

        startHoax(address(this));
        eTST.setInterestFee(0.1e4);

        // Values generated with: node calculate-irm-linear-kink.js supply 0 7 90 50 10
        //   7% supply APY is scaled up to 15.56 borrow APY
        // Base=0.00% APY,  Kink(50.00%)=15.56% APY  Max=100.00% APY
        eTST.setInterestRateModel(irmFactory.deploy(0, 2133472229, 8094759195, 2147483648));

        startHoax(user3);
        eTST.borrow(0.5e18, user3);

        (uint256 borrowAPY, uint256 supplyAPY) = getVaultInfo(address(eTST));

        assertApproxEqAbs(borrowAPY, 0.1556e27, 0.0001e27);
        assertApproxEqAbs(supplyAPY, 0.07e27, 0.0001e27);

        {
            VaultInfoFull memory info = vaultLens.getVaultInfoFull(address(eTST));

            assertApproxEqAbs(info.irmInfo.interestRateInfo[0].borrowAPY, 0.1556e27, 0.0001e27);
            assertApproxEqAbs(info.irmInfo.interestRateInfo[0].supplyAPY, 0.07e27, 0.0001e27);
        }

        skip(365.2425 days);

        // Borrower's debt has increased by 15.56%
        assertApproxEqAbs(eTST.debtOf(user3), 0.5e18 * 1.1556e18 / 1e18, 0.0001e18);

        // Depositor has earned 7.00%
        assertApproxEqAbs(eTST.convertToAssets(eTST.balanceOf(user1)), 1.07e18, 0.0001e18);
    }

    function getVaultInfo(address vault)
        internal
        view
        returns (uint256 borrowInterestRateAPY, uint256 supplyInterestRateAPY)
    {
        uint256 interestFee = IEVault(vault).interestFee();
        uint256 borrowInterestRateSPY = IEVault(vault).interestRate();
        uint256 totalCash = IEVault(vault).cash();
        uint256 totalBorrowed = IEVault(vault).totalBorrows();
        return computeInterestRates(borrowInterestRateSPY, totalCash, totalBorrowed, interestFee);
    }

    function computeInterestRates(uint256 borrowSPY, uint256 cash, uint256 borrows, uint256 interestFee)
        internal
        view
        returns (uint256 borrowAPY, uint256 supplyAPY)
    {
        uint256 totalAssets = cash + borrows;
        bool overflowBorrow;

        (borrowAPY, overflowBorrow) = RPow.rpow(borrowSPY + ONE, SECONDS_PER_YEAR, ONE);
        if (overflowBorrow) return (0, 0);
        borrowAPY -= ONE;

        supplyAPY =
            totalAssets == 0 ? 0 : borrowAPY * borrows * (CONFIG_SCALE - interestFee) / totalAssets / CONFIG_SCALE;
    }
}
