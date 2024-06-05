// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IPriceOracle} from "euler-price-oracle/interfaces/IPriceOracle.sol";
import "./LensTypes.sol";

interface IOracle is IPriceOracle {
    function base() external view returns (address);
    function quote() external view returns (address);
    function cross() external view returns (address);
    function oracleBaseCross() external view returns (address);
    function oracleCrossQuote() external view returns (address);
    function feed() external view returns (address);
    function pyth() external view returns (address);
    function STETH() external view returns (address);
    function WSTETH() external view returns (address);
    function tokenA() external view returns (address);
    function tokenB() external view returns (address);
    function pool() external view returns (address);
    function governor() external view returns (address);
    function maxStaleness() external view returns (uint256);
    function maxConfWidth() external view returns (uint256);
    function twapWindow() external view returns (uint32);
    function fee() external view returns (uint24);
    function feedDecimals() external view returns (uint8);
    function feedId() external view returns (bytes32);
    function fallbackOracle() external view returns (address);
    function resolvedVaults(address) external view returns (address);
    function cache() external view returns (uint208, uint48);
    function resolveOracle(uint256 inAmount, address base, address quote)
        external
        view
        returns (uint256, address, address, address);
    function getConfiguredOracle(address base, address quote) external view returns (address);
}

contract OracleLens {
    function getOracleInfo(address oracleAddress, address[] calldata bases, address unitOfAccount)
        public
        view
        returns (OracleDetailedInfo memory)
    {
        if (oracleAddress == address(0)) {
            return OracleDetailedInfo({name: "", oracleInfo: ""});
        }

        IOracle oracle = IOracle(oracleAddress);
        string memory name = oracle.name();
        bytes memory oracleInfo;

        if (strEq(name, "ChainlinkOracle")) {
            oracleInfo = abi.encode(
                ChainlinkOracleInfo({
                    base: oracle.base(),
                    quote: oracle.quote(),
                    feed: oracle.feed(),
                    maxStaleness: oracle.maxStaleness()
                })
            );
        } else if (strEq(name, "ChronicleOracle")) {
            oracleInfo = abi.encode(
                ChronicleOracleInfo({
                    base: oracle.base(),
                    quote: oracle.quote(),
                    feed: oracle.feed(),
                    maxStaleness: oracle.maxStaleness()
                })
            );
        } else if (strEq(name, "LidoOracle")) {
            oracleInfo = abi.encode(LidoOracleInfo({base: oracle.WSTETH(), quote: oracle.STETH()}));
        } else if (strEq(name, "PythOracle")) {
            oracleInfo = abi.encode(
                PythOracleInfo({
                    pyth: oracle.pyth(),
                    base: oracle.base(),
                    quote: oracle.quote(),
                    feedId: oracle.feedId(),
                    maxStaleness: oracle.maxStaleness(),
                    maxConfWidth: oracle.maxConfWidth()
                })
            );
        } else if (strEq(name, "RedstoneCoreOracle")) {
            (uint208 cachePrice, uint48 cachePriceTimestamp) = oracle.cache();
            oracleInfo = abi.encode(
                RedstoneCoreOracleInfo({
                    base: oracle.base(),
                    quote: oracle.quote(),
                    feedId: oracle.feedId(),
                    maxStaleness: oracle.maxStaleness(),
                    feedDecimals: oracle.feedDecimals(),
                    cachePrice: cachePrice,
                    cachePriceTimestamp: cachePriceTimestamp
                })
            );
        } else if (strEq(name, "UniswapV3Oracle")) {
            oracleInfo = abi.encode(
                UniswapV3OracleInfo({
                    tokenA: oracle.tokenA(),
                    tokenB: oracle.tokenB(),
                    pool: oracle.pool(),
                    fee: oracle.fee(),
                    twapWindow: oracle.twapWindow()
                })
            );
        } else if (strEq(name, "CrossAdapter")) {
            address oracleBaseCross = oracle.oracleBaseCross();
            address oracleCrossQuote = oracle.oracleCrossQuote();
            OracleDetailedInfo memory oracleBaseCrossInfo = getOracleInfo(oracleBaseCross, bases, unitOfAccount);
            OracleDetailedInfo memory oracleCrossQuoteInfo = getOracleInfo(oracleCrossQuote, bases, unitOfAccount);
            oracleInfo = abi.encode(
                CrossAdapterInfo({
                    base: oracle.base(),
                    cross: oracle.cross(),
                    quote: oracle.quote(),
                    oracleBaseCross: oracleBaseCross,
                    oracleCrossQuote: oracleCrossQuote,
                    oracleBaseCrossInfo: oracleBaseCrossInfo,
                    oracleCrossQuoteInfo: oracleCrossQuoteInfo
                })
            );
        } else if (strEq(name, "EulerRouter")) {
            address[] memory resolvedOracles = new address[](bases.length);
            OracleDetailedInfo[] memory resolvedOraclesInfo = new OracleDetailedInfo[](bases.length);
            for (uint256 i = 0; i < bases.length; ++i) {
                try oracle.resolveOracle(0, bases[i], unitOfAccount) returns (
                    uint256, address, address, address resolvedOracle
                ) {
                    resolvedOracles[i] = resolvedOracle;
                    resolvedOraclesInfo[i] = getOracleInfo(resolvedOracle, bases, unitOfAccount);
                } catch {
                    resolvedOracles[i] = address(0);
                    resolvedOraclesInfo[i] = OracleDetailedInfo({name: "", oracleInfo: ""});
                }
            }

            address fallbackOracle = oracle.fallbackOracle();

            oracleInfo = abi.encode(
                EulerRouterInfo({
                    governor: oracle.governor(),
                    fallbackOracle: oracle.fallbackOracle(),
                    fallbackOracleInfo: getOracleInfo(fallbackOracle, bases, unitOfAccount),
                    resolvedOracles: resolvedOracles,
                    resolvedOraclesInfo: resolvedOraclesInfo
                })
            );
        }

        return OracleDetailedInfo({name: name, oracleInfo: oracleInfo});
    }
    
    function strEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
