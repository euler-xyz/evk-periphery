// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";

// source: https://github.com/memester-xyz/surl
// modified to work with --data-binary option of curl

library Surl {
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
    string constant bodyFileName = "body.json";

    function get(string memory self) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return get(self, empty);
    }

    function get(string memory self, string[] memory headers) internal returns (uint256 status, bytes memory data) {
        return curl(self, headers, "", "GET");
    }

    function del(string memory self) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, "", "DELETE");
    }

    function del(string memory self, string memory body) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, body, "DELETE");
    }

    function del(string memory self, string[] memory headers, string memory body)
        internal
        returns (uint256 status, bytes memory data)
    {
        return curl(self, headers, body, "DELETE");
    }

    function patch(string memory self) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, "", "PATCH");
    }

    function patch(string memory self, string memory body) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, body, "PATCH");
    }

    function patch(string memory self, string[] memory headers, string memory body)
        internal
        returns (uint256 status, bytes memory data)
    {
        return curl(self, headers, body, "PATCH");
    }

    function post(string memory self) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, "", "POST");
    }

    function post(string memory self, string memory body) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, body, "POST");
    }

    function post(string memory self, string[] memory headers, string memory body)
        internal
        returns (uint256 status, bytes memory data)
    {
        return curl(self, headers, body, "POST");
    }

    function put(string memory self) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, "", "PUT");
    }

    function put(string memory self, string memory body) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, body, "PUT");
    }

    function put(string memory self, string[] memory headers, string memory body)
        internal
        returns (uint256 status, bytes memory data)
    {
        return curl(self, headers, body, "PUT");
    }

    function getBodyFileName() internal view returns (string memory) {
        return string.concat(vm.projectRoot(), "/script/", bodyFileName);
    }

    function curl(string memory self, string[] memory headers, string memory body, string memory method)
        internal
        returns (uint256 status, bytes memory data)
    {
        string memory scriptStart = 'response=$(curl -s -w "\\n%{http_code}" ';
        string memory scriptEnd =
            '); status=$(tail -n1 <<< "$response"); data=$(sed "$ d" <<< "$response");data=$(echo "$data" | tr -d "\\n"); cast abi-encode "response(uint256,string)" "$status" "$data";';

        string memory curlParams = "";

        for (uint256 i = 0; i < headers.length; i++) {
            curlParams = string.concat(curlParams, '-H "', headers[i], '" ');
        }

        curlParams = string.concat(curlParams, " -X ", method, " ");

        uint256 bodyLength = bytes(body).length;
        if (bodyLength > 0) {
            curlParams = string.concat(curlParams, " --data-binary @", getBodyFileName(), " ");
        }

        string memory quotedURL = string.concat('"', self, '"');

        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = string.concat(scriptStart, curlParams, quotedURL, scriptEnd, "");

        bytes memory res;
        if (bodyLength > 0) {
            string memory fileName = getBodyFileName();
            vm.writeJson(body, fileName);
            res = vm.ffi(inputs);
            vm.removeFile(fileName);
        } else {
            res = vm.ffi(inputs);
        }

        (status, data) = abi.decode(res, (uint256, bytes));
    }
}
