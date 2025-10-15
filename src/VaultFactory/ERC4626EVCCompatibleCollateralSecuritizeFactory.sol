// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseFactory} from "../BaseFactory/BaseFactory.sol";
import {ERC4626EVCCompatibleCollateralSecuritize} from "../Vault/deployed/ERC4626EVCCompatibleCollateralSecuritize.sol";
import {IERC4626EVCCompatibleCollateralSecuritizeFactory} from
    "./interfaces/IERC4626EVCCompatibleCollateralSecuritizeFactory.sol";

/// @title ERC4626EVCCompatibleCollateralSecuritizeFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for ERC4626EVKCompatibleCollateralSecuritize vaults.
contract ERC4626EVCCompatibleCollateralSecuritizeFactory is
    BaseFactory,
    IERC4626EVCCompatibleCollateralSecuritizeFactory
{
    /// @notice The address of the EVC.
    address public immutable evc;

    /// @notice The address of the Permit2.
    address public immutable permit2;

    /// @notice Constructs the factory for ERC4626EVCCompatibleCollateralSecuritize vaults.
    /// @param _evc The address of the EVC.
    /// @param _permit2 The address of the Permit2.
    constructor(address _evc, address _permit2) {
        evc = _evc;
        permit2 = _permit2;
    }

    /// @notice Deploys a new ERC4626EVCCompatibleCollateralSecuritize vault.
    /// @param asset The address of the underlying asset for the new vault.
    /// @param name The name of the new vault.
    /// @param symbol The symbol of the new vault.
    /// @return The deployment address.
    function deploy(address asset, string memory name, string memory symbol) external override returns (address) {
        address vault =
            address(new ERC4626EVCCompatibleCollateralSecuritize(evc, permit2, msg.sender, asset, name, symbol));

        deploymentInfo[vault] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        deployments.push(vault);
        emit ContractDeployed(vault, msg.sender, block.timestamp);
        return vault;
    }
}
