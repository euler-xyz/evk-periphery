// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {TermsOfUseSigner} from "../src/TermsOfUseSigner/TermsOfUseSigner.sol";

contract TermsOfUseSignerDeployer is ScriptUtils {
    function run() public broadcast returns (address termsOfUseSigner) {
        string memory inputScriptFileName = "13_TermsOfUseSigner_input.json";
        string memory outputScriptFileName = "13_TermsOfUseSigner_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");

        termsOfUseSigner = execute(evc);

        string memory object;
        object = vm.serializeAddress("termsOfUseSigner", "termsOfUseSigner", termsOfUseSigner);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc) public broadcast returns (address termsOfUseSigner) {
        termsOfUseSigner = execute(evc);
    }

    function execute(address evc) public returns (address termsOfUseSigner) {
        termsOfUseSigner = address(new TermsOfUseSigner(evc));
    }
}
