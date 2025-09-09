// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Utils} from "./Utils.sol";
import {SnapshotRegistry} from "../SnapshotRegistry/SnapshotRegistry.sol";
import {IPriceOracle} from "euler-price-oracle/interfaces/IPriceOracle.sol";
import {Errors} from "euler-price-oracle/lib/Errors.sol";
import "./LensTypes.sol";

interface IOracle is IPriceOracle {
    function base() external view returns (address);
    function quote() external view returns (address);
    function cross() external view returns (address);
    function oracleBaseCross() external view returns (address);
    function oracleCrossQuote() external view returns (address);
    function feed() external view returns (address);
    function pyth() external view returns (address);
    function WETH() external view returns (address);
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
    function rate() external view returns (uint256);
    function rateProvider() external view returns (address);
    function rwaOracle() external view returns (address);
    function resolveOracle(uint256 inAmount, address base, address quote)
        external
        view
        returns (uint256, address, address, address);
    function getConfiguredOracle(address base, address quote) external view returns (address);
    function description() external view returns (string memory);
    function pendleMarket() external view returns (address);
    function safeguardPool() external view returns (address);
    function poolId() external view returns (bytes32);
    function priceOracleIndex() external view returns (uint256);
}

contract OracleLens is Utils {
    SnapshotRegistry public immutable adapterRegistry;

    constructor(address _adapterRegistry) {
        adapterRegistry = SnapshotRegistry(_adapterRegistry);
    }

    function getOracleInfo(address oracleAddress, address[] memory bases, address[] memory quotes)
        public
        view
        returns (OracleDetailedInfo memory)
    {
        string memory name;
        bytes memory oracleInfo;

        {
            bool success;
            bytes memory result;

            if (oracleAddress != address(0)) {
                (success, result) = oracleAddress.staticcall(abi.encodeCall(IPriceOracle.name, ()));
            }

            if (success && result.length >= 32) {
                name = abi.decode(result, (string));
            } else {
                return OracleDetailedInfo({oracle: oracleAddress, name: "", oracleInfo: ""});
            }
        }

        if (_strEq(name, "ChainlinkOracle")) {
            (bool success, bytes memory result) =
                IOracle(oracleAddress).feed().staticcall(abi.encodeCall(IOracle.description, ()));
            string memory feedDescription = success && result.length >= 32 ? abi.decode(result, (string)) : "";

            oracleInfo = abi.encode(
                ChainlinkOracleInfo({
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    feed: IOracle(oracleAddress).feed(),
                    feedDescription: feedDescription,
                    maxStaleness: IOracle(oracleAddress).maxStaleness()
                })
            );
        } else if (_strEq(name, "ChainlinkInfrequentOracle")) {
            (bool success, bytes memory result) =
                IOracle(oracleAddress).feed().staticcall(abi.encodeCall(IOracle.description, ()));
            string memory feedDescription = success && result.length >= 32 ? abi.decode(result, (string)) : "";

            oracleInfo = abi.encode(
                ChainlinkInfrequentOracleInfo({
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    feed: IOracle(oracleAddress).feed(),
                    feedDescription: feedDescription,
                    maxStaleness: IOracle(oracleAddress).maxStaleness()
                })
            );
        } else if (_strEq(name, "ChronicleOracle")) {
            oracleInfo = abi.encode(
                ChronicleOracleInfo({
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    feed: IOracle(oracleAddress).feed(),
                    maxStaleness: IOracle(oracleAddress).maxStaleness()
                })
            );
        } else if (_strEq(name, "LidoOracle")) {
            oracleInfo = abi.encode(
                LidoOracleInfo({base: IOracle(oracleAddress).WSTETH(), quote: IOracle(oracleAddress).STETH()})
            );
        } else if (_strEq(name, "LidoFundamentalOracle")) {
            oracleInfo = abi.encode(
                LidoFundamentalOracleInfo({base: IOracle(oracleAddress).WSTETH(), quote: IOracle(oracleAddress).WETH()})
            );
        } else if (_strEq(name, "PythOracle")) {
            oracleInfo = abi.encode(
                PythOracleInfo({
                    pyth: IOracle(oracleAddress).pyth(),
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    feedId: IOracle(oracleAddress).feedId(),
                    maxStaleness: IOracle(oracleAddress).maxStaleness(),
                    maxConfWidth: IOracle(oracleAddress).maxConfWidth()
                })
            );
        } else if (_strEq(name, "RedstoneCoreOracle")) {
            (uint208 cachePrice, uint48 cachePriceTimestamp) = IOracle(oracleAddress).cache();
            oracleInfo = abi.encode(
                RedstoneCoreOracleInfo({
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    feedId: IOracle(oracleAddress).feedId(),
                    maxStaleness: IOracle(oracleAddress).maxStaleness(),
                    feedDecimals: IOracle(oracleAddress).feedDecimals(),
                    cachePrice: cachePrice,
                    cachePriceTimestamp: cachePriceTimestamp
                })
            );
        } else if (_strEq(name, "UniswapV3Oracle")) {
            oracleInfo = abi.encode(
                UniswapV3OracleInfo({
                    tokenA: IOracle(oracleAddress).tokenA(),
                    tokenB: IOracle(oracleAddress).tokenB(),
                    pool: IOracle(oracleAddress).pool(),
                    fee: IOracle(oracleAddress).fee(),
                    twapWindow: IOracle(oracleAddress).twapWindow()
                })
            );
        } else if (_strEq(name, "FixedRateOracle")) {
            oracleInfo = abi.encode(
                FixedRateOracleInfo({
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    rate: IOracle(oracleAddress).rate()
                })
            );
        } else if (_strEq(name, "RateProviderOracle")) {
            oracleInfo = abi.encode(
                RateProviderOracleInfo({
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    rateProvider: IOracle(oracleAddress).rateProvider()
                })
            );
        } else if (_strEq(name, "OndoOracle")) {
            oracleInfo = abi.encode(
                OndoOracleInfo({
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    rwaOracle: IOracle(oracleAddress).rwaOracle()
                })
            );
        } else if (_strEq(name, "PendleOracle")) {
            oracleInfo = abi.encode(
                PendleProviderOracleInfo({
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    pendleMarket: IOracle(oracleAddress).pendleMarket(),
                    twapWindow: IOracle(oracleAddress).twapWindow()
                })
            );
        } else if (_strEq(name, "PendleUniversalOracle")) {
            oracleInfo = abi.encode(
                PendleUniversalOracleInfo({
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    pendleMarket: IOracle(oracleAddress).pendleMarket(),
                    twapWindow: IOracle(oracleAddress).twapWindow()
                })
            );
        } else if (_strEq(name, "CurveEMAOracle")) {
            oracleInfo = abi.encode(
                CurveEMAOracleInfo({
                    base: IOracle(oracleAddress).base(),
                    quote: IOracle(oracleAddress).quote(),
                    pool: IOracle(oracleAddress).pool(),
                    priceOracleIndex: IOracle(oracleAddress).priceOracleIndex()
                })
            );
        } else if (_strEq(name, "SwaapSafeguardOracle")) {
            oracleInfo = abi.encode(
                SwaapSafeguardProviderOracleInfo({
                    base: IOracle(oracleAddress).safeguardPool(),
                    quote: IOracle(oracleAddress).quote(),
                    poolId: IOracle(oracleAddress).poolId()
                })
            );
        } else if (_strEq(name, "CrossAdapter")) {
            address oracleBaseCross = IOracle(oracleAddress).oracleBaseCross();
            address oracleCrossQuote = IOracle(oracleAddress).oracleCrossQuote();
            OracleDetailedInfo memory oracleBaseCrossInfo = getOracleInfo(oracleBaseCross, bases, quotes);
            OracleDetailedInfo memory oracleCrossQuoteInfo = getOracleInfo(oracleCrossQuote, bases, quotes);
            oracleInfo = abi.encode(
                CrossAdapterInfo({
                    base: IOracle(oracleAddress).base(),
                    cross: IOracle(oracleAddress).cross(),
                    quote: IOracle(oracleAddress).quote(),
                    oracleBaseCross: oracleBaseCross,
                    oracleCrossQuote: oracleCrossQuote,
                    oracleBaseCrossInfo: oracleBaseCrossInfo,
                    oracleCrossQuoteInfo: oracleCrossQuoteInfo
                })
            );
        } else if (_strEq(name, "EulerRouter")) {
            require(bases.length == quotes.length, "OracleLens: invalid input");

            address[][] memory resolvedAssets = new address[][](bases.length);
            address[] memory resolvedOracles = new address[](bases.length);
            OracleDetailedInfo[] memory resolvedOraclesInfo = new OracleDetailedInfo[](bases.length);

            for (uint256 i = 0; i < bases.length; ++i) {
                (resolvedAssets[i], resolvedOracles[i], resolvedOraclesInfo[i]) =
                    _routerResolve(oracleAddress, resolvedAssets[i], bases[i], quotes[i]);
            }

            address fallbackOracle = IOracle(oracleAddress).fallbackOracle();

            oracleInfo = abi.encode(
                EulerRouterInfo({
                    governor: IOracle(oracleAddress).governor(),
                    fallbackOracle: fallbackOracle,
                    fallbackOracleInfo: getOracleInfo(fallbackOracle, bases, quotes),
                    bases: bases,
                    quotes: quotes,
                    resolvedAssets: resolvedAssets,
                    resolvedOracles: resolvedOracles,
                    resolvedOraclesInfo: resolvedOraclesInfo
                })
            );
        }

        return OracleDetailedInfo({oracle: oracleAddress, name: name, oracleInfo: oracleInfo});
    }

    function isStalePullOracle(address oracleAddress, bytes calldata failureReason) public view returns (bool) {
        bytes4 failureReasonSelector = bytes4(failureReason);
        return _isStalePythOracle(oracleAddress, failureReasonSelector)
            || _isStaleRedstoneOracle(oracleAddress, failureReasonSelector)
            || _isStaleCrossAdapter(oracleAddress, failureReasonSelector);
    }

    function getValidAdapters(address base, address quote) public view returns (address[] memory) {
        return adapterRegistry.getValidAddresses(base, quote, block.timestamp);
    }

    function _routerResolve(
        address oracleAddress,
        address[] memory currentlyResolvedAssets,
        address base,
        address quote
    )
        internal
        view
        returns (address[] memory resolvedAssets, address resolvedOracle, OracleDetailedInfo memory resolvedOracleInfo)
    {
        if (base == quote) return (currentlyResolvedAssets, resolvedOracle, resolvedOracleInfo);

        (bool success, bytes memory result) =
            oracleAddress.staticcall(abi.encodeCall(IOracle.getConfiguredOracle, (base, quote)));

        if (!success || result.length < 32) return (currentlyResolvedAssets, resolvedOracle, resolvedOracleInfo);

        resolvedOracle = abi.decode(result, (address));

        if (resolvedOracle != address(0)) {
            address[] memory bases = new address[](1);
            address[] memory quotes = new address[](1);
            bases[0] = base;
            quotes[0] = quote;
            resolvedOracleInfo = getOracleInfo(resolvedOracle, bases, quotes);
            return (currentlyResolvedAssets, resolvedOracle, resolvedOracleInfo);
        }

        (success, result) = oracleAddress.staticcall(abi.encodeCall(IOracle.resolvedVaults, (base)));

        if (!success || result.length < 32) return (currentlyResolvedAssets, resolvedOracle, resolvedOracleInfo);

        address baseAsset = abi.decode(result, (address));

        if (baseAsset != address(0)) {
            resolvedAssets = new address[](currentlyResolvedAssets.length + 1);
            for (uint256 i = 0; i < currentlyResolvedAssets.length; ++i) {
                resolvedAssets[i] = currentlyResolvedAssets[i];
            }
            resolvedAssets[resolvedAssets.length - 1] = baseAsset;
            return _routerResolve(oracleAddress, resolvedAssets, baseAsset, quote);
        }

        (success, result) = oracleAddress.staticcall(abi.encodeCall(IOracle.fallbackOracle, ()));

        if (!success || result.length < 32) return (currentlyResolvedAssets, resolvedOracle, resolvedOracleInfo);

        resolvedOracle = abi.decode(result, (address));

        if (resolvedOracle != address(0)) {
            address[] memory bases = new address[](1);
            address[] memory quotes = new address[](1);
            bases[0] = base;
            quotes[0] = quote;
            resolvedOracleInfo = getOracleInfo(resolvedOracle, bases, quotes);
            return (currentlyResolvedAssets, resolvedOracle, resolvedOracleInfo);
        }

        return (currentlyResolvedAssets, resolvedOracle, resolvedOracleInfo);
    }

    function _isStalePythOracle(address oracle, bytes4 failureSelector) internal view returns (bool) {
        if (oracle == address(0)) return false;

        (bool success, bytes memory result) = oracle.staticcall(abi.encodeCall(IPriceOracle.name, ()));

        if (success && result.length >= 32) {
            string memory name = abi.decode(result, (string));
            return _strEq(name, "PythOracle") && failureSelector == Errors.PriceOracle_InvalidAnswer.selector;
        }

        return false;
    }

    function _isStaleRedstoneOracle(address oracle, bytes4 failureSelector) internal view returns (bool) {
        if (oracle == address(0)) return false;

        (bool success, bytes memory result) = oracle.staticcall(abi.encodeCall(IPriceOracle.name, ()));

        if (success && result.length >= 32) {
            string memory name = abi.decode(result, (string));
            return _strEq(name, "RedstoneCoreOracle") && failureSelector == Errors.PriceOracle_TooStale.selector;
        }

        return false;
    }

    function _isStaleCrossAdapter(address oracle, bytes4 failureSelector) internal view returns (bool) {
        if (oracle == address(0)) return false;

        (bool success, bytes memory result) = oracle.staticcall(abi.encodeCall(IPriceOracle.name, ()));

        if (success && result.length >= 32) {
            string memory name = abi.decode(result, (string));
            if (!_strEq(name, "CrossAdapter")) return false;
        } else {
            return false;
        }

        address oracleBaseCross = IOracle(oracle).oracleBaseCross();
        address oracleCrossQuote = IOracle(oracle).oracleCrossQuote();

        return _isStalePythOracle(oracleBaseCross, failureSelector)
            || _isStaleRedstoneOracle(oracleBaseCross, failureSelector)
            || _isStalePythOracle(oracleCrossQuote, failureSelector)
            || _isStaleRedstoneOracle(oracleCrossQuote, failureSelector)
            || _isStaleCrossAdapter(oracleBaseCross, failureSelector)
            || _isStaleCrossAdapter(oracleCrossQuote, failureSelector);
    }
}
