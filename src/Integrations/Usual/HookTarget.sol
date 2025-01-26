// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault} from "evk/EVault/IEVault.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {HookTargetAccessControl} from "../../HookTarget/HookTargetAccessControl.sol";
import {ERC20BurnableMintable} from "../../ERC20/deployed/ERC20BurnableMintable.sol";

/// @title HookTarget
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that provides a custom behavior for the EVK vault.
contract HookTarget is HookTargetAccessControl {
    IEVault public immutable eVault;
    ERC20BurnableMintable public immutable dToken;
    address public treasury;

    /// @notice Emitted when the treasury address is updated
    /// @param oldTreasury The old treasury address
    /// @param newTreasury The new treasury address
    event TreasurySet(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Initializes the HookTarget contract
    /// @param _evc The address of the EVC
    /// @param _admin The address to be granted the DEFAULT_ADMIN_ROLE
    /// @param _eVaultFactory The address of the EVault factory
    /// @param _eVault The address of the EVault contract
    /// @param _treasury The address of the treasury that will receive minted debt tokens
    constructor(address _evc, address _admin, address _eVaultFactory, address _eVault, address _treasury)
        HookTargetAccessControl(_evc, _admin, _eVaultFactory)
    {
        require(GenericFactory(_eVaultFactory).isProxy(_eVault), "Invalid factory or vault");
        require(IEVault(_eVault).EVC() == _evc, "Invalid EVC");
        require(_admin != address(0), "Invalid admin");
        require(_treasury != address(0), "Invalid treasury");

        eVault = IEVault(_eVault);
        treasury = _treasury;
        emit TreasurySet(address(0), _treasury);

        dToken = new ERC20BurnableMintable(
            address(this),
            string.concat("Global debt token of ", eVault.name()),
            string.concat(eVault.symbol(), "-GLOBAL-DEBT"),
            eVault.decimals()
        );
        dToken.grantRole(dToken.MINTER_ROLE(), address(this));
        dToken.renounceRole(dToken.DEFAULT_ADMIN_ROLE(), address(this));
    }

    /// @notice Updates the treasury address
    /// @param _treasury The new treasury address
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasury != address(0) && _treasury != treasury) {
            emit TreasurySet(treasury, _treasury);
            treasury = _treasury;
        }
    }

    /// @notice Checks the vault's debt status and mints debt tokens if needed
    /// @dev If the vault's total borrows exceeds the debt token supply, mints the difference to the treasury
    /// @return The function selector (0) to indicate successful execution
    function checkVaultStatus() external returns (bytes4) {        
        uint256 eVaultTotalDebt = eVault.totalBorrows();
        uint256 dTokenTotalDebt = dToken.totalSupply();

        if (eVaultTotalDebt > dTokenTotalDebt) {
            dToken.mint(treasury, eVaultTotalDebt - dTokenTotalDebt);
        }

        return 0;
    }
}
