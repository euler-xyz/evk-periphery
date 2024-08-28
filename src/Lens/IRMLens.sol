// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Utils} from "./Utils.sol";
import {IFactory} from "../BaseFactory/interfaces/IFactory.sol";
import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import "./LensTypes.sol";

contract IRMLens is Utils {
    address public immutable kinkIRMFactory;

    constructor(address _kinkIRMFactory) {
        kinkIRMFactory = _kinkIRMFactory;
    }

    function getInterestRateModelInfo(address irm) public view returns (InterestRateModelDetailedInfo memory) {
        InterestRateModelDetailedInfo memory result;

        if (irm == address(0)) {
            return result;
        }

        result.interestRateModel = irm;

        if (IFactory(kinkIRMFactory).isValidDeployment(irm)) {
            result.interestRateModelType = InterestRateModelType.KINK;
            result.interestRateModelParams = abi.encode(
                KinkIRMInfo({
                    baseRate: IRMLinearKink(irm).baseRate(),
                    slope1: IRMLinearKink(irm).slope1(),
                    slope2: IRMLinearKink(irm).slope2(),
                    kink: IRMLinearKink(irm).kink()
                })
            );
        }

        return result;
    }
}
