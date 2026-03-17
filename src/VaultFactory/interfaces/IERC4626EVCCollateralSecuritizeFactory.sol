// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {IFactory} from "../../BaseFactory/interfaces/IFactory.sol";

/// @title IERC4626EVCCollateralSecuritizeFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Factory interface for ERC4626EVCCollateralSecuritize vaults.
interface IERC4626EVCCollateralSecuritizeFactory is IFactory {
    /// @notice Deploys a new ERC4626EVCCollateralSecuritize.
    /// @param controllerPerspective The address of the perspective contract whitelisting controllers able to liquidate
    /// the new vault.
    /// @param asset The address of the underlying asset for the new vault.
    /// @param name The name of the new vault.
    /// @param symbol The symbol of the new vault.
    /// @return The deployment address.
    function deploy(address controllerPerspective, address asset, string memory name, string memory symbol)
        external
        returns (address);
}
