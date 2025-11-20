// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC4626EVCCollateral, ERC4626EVC} from "../../../src/Vault/implementation/ERC4626EVCCollateral.sol";
import {ERC4626EVCCollateralCapped} from "../../../src/Vault/implementation/ERC4626EVCCollateralCapped.sol";
import {ERC4626EVCCollateralFreezable} from "../../../src/Vault/implementation/ERC4626EVCCollateralFreezable.sol";

contract ERC4626EVCCollateralHarness is ERC4626EVCCollateral {
    constructor(address evc, address permit2, address underlying, string memory name, string memory symbol)
        ERC4626EVC(evc, permit2, underlying, name, symbol)
    {}

    function mockSetTotalAssets(uint256 value) public {
        _totalAssets = value;
    }
}

contract ERC4626EVCCollateralCappedHarness is ERC4626EVCCollateralCapped {
    constructor(
        address admin,
        address evc,
        address permit2,
        address underlying,
        string memory name,
        string memory symbol
    ) ERC4626EVC(evc, permit2, underlying, name, symbol) ERC4626EVCCollateralCapped(admin) {}

    function _updateCache() internal override {}

    function mockInitializeFeature(uint8 index) public {
        _initializeFeature(index);
    }

    function mockDisableFeature(uint8 index) public {
        _disableFeature(index);
    }

    function mockEnableFeature(uint8 index) public {
        _enableFeature(index);
    }

    function mockIsEnabled(uint8 index) public view returns (bool) {
        return _isEnabled(index);
    }
}

contract ERC4626EVCCollateralFreezableHarness is ERC4626EVCCollateralFreezable {
    constructor(
        address admin,
        address evc,
        address permit2,
        address underlying,
        string memory name,
        string memory symbol
    )
        ERC4626EVC(evc, permit2, underlying, name, symbol)
        ERC4626EVCCollateralCapped(admin)
        ERC4626EVCCollateralFreezable()
    {}

    function _updateCache() internal override {}

    function mockInitializeFeature(uint8 index) public {
        _initializeFeature(index);
    }

    function mockDisableFeature(uint8 index) public {
        _disableFeature(index);
    }

    function mockEnableFeature(uint8 index) public {
        _enableFeature(index);
    }

    function mockIsEnabled(uint8 index) public view returns (bool) {
        return _isEnabled(index);
    }
}
