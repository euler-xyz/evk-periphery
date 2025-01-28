// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {IEdgeFactory} from "../../EdgeFactory/interfaces/IEdgeFactory.sol";
import {BasePerspective} from "../implementation/BasePerspective.sol";

/// @title EdgeFactoryPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault was deployed by the Edge Factory.
contract EdgeFactoryPerspective is BasePerspective {
    /// @notice Creates a new EdgeFactoryPerspective instance.
    /// @param edgeFactory_ The address of the EdgeFactory contract.
    constructor(address edgeFactory_) BasePerspective(edgeFactory_) {}

    /// @inheritdoc BasePerspective
    function name() public pure virtual override returns (string memory) {
        return "Edge Factory Perspective";
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address vault) internal virtual override {
        testProperty(IEdgeFactory(address(vaultFactory)).isDeployed(vault), ERROR__FACTORY);
    }

    /// @inheritdoc BasePerspective
    function isVerified(address vault) public view virtual override returns (bool) {
        return IEdgeFactory(address(vaultFactory)).isDeployed(vault);
    }

    /// @inheritdoc BasePerspective
    function verifiedLength() public view virtual override returns (uint256) {
        address[][] memory list = IEdgeFactory(address(vaultFactory)).getDeploymentsListSlice(0, type(uint256).max);

        uint256 count;
        for (uint256 i = 0; i < list.length; ++i) {
            count += list[i].length;
        }

        return count;
    }

    /// @inheritdoc BasePerspective
    function verifiedArray() public view virtual override returns (address[] memory) {
        address[][] memory list = IEdgeFactory(address(vaultFactory)).getDeploymentsListSlice(0, type(uint256).max);

        uint256 count;
        for (uint256 i = 0; i < list.length; ++i) {
            count += list[i].length;
        }

        address[] memory result = new address[](count);
        count = 0;

        for (uint256 i = 0; i < list.length; ++i) {
            for (uint256 j = 0; j < list[i].length; ++j) {
                result[count++] = list[i][j];
            }
        }

        return result;
    }
}
