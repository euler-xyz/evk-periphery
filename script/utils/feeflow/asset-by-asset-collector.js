#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const PriceFetcher = require('./price-fetcher');
const { createPublicClient, http } = require('viem');

// Load environment variables from the root directory
require('dotenv').config({ path: path.join(__dirname, '../../../.env') });

/**
 * Asset-by-Asset Price Collector for FeeFlow Efficiency Analysis
 * 
 * This script:
 * 1. Handles one asset at a time (e.g., USDC on Ethereum first)
 * 2. Builds cross-chain mappings gradually as we discover them
 * 3. Saves data frequently to enable resuming anytime
 * 4. Focuses on assets we can actually get prices for
 */

class AssetByAssetCollector {
  constructor(options = {}) {
    this.priceFetcher = new PriceFetcher();
    this.priceData = { assets: {} };
    this.assetMappings = new Map(); // Cross-chain asset mappings
    this.failedAssets = new Set(); // Assets that consistently fail
    
    // Configuration options
    this.targetAsset = options.targetAsset || null; // Specific asset to process
    this.outputFile = options.outputFile || 'feeflow-asset-prices.json';
    this.mappingsFile = options.mappingsFile || 'asset-mappings.json';
    this.failedAssetsFile = options.failedAssetsFile || 'failed-assets.json';
    
    // Progress tracking
    this.progress = {
      currentAsset: null,
      processedAssets: 0,
      totalAssets: 0,
      startTime: null,
      lastSaveTime: null
    };
  }

  /**
   * Load existing data and mappings
   */
  loadExistingData() {
    // Load existing price data
    try {
      if (fs.existsSync(this.outputFile)) {
        const data = fs.readFileSync(this.outputFile, 'utf8');
        this.priceData = JSON.parse(data);
        console.log(`Loaded existing price data: ${Object.keys(this.priceData.assets || {}).length} assets`);
      }
    } catch (error) {
      console.log(`Could not load existing price data: ${error.message}`);
    }
    
    // Ensure priceData.assets exists
    if (!this.priceData.assets) {
      this.priceData.assets = {};
      console.log(`Initialized empty priceData.assets`);
    }

    // Load existing asset mappings
    try {
      if (fs.existsSync(this.mappingsFile)) {
        const data = fs.readFileSync(this.mappingsFile, 'utf8');
        this.assetMappings = new Map(Object.entries(JSON.parse(data)));
        console.log(`Loaded existing asset mappings: ${this.assetMappings.size} mappings`);
      }
    } catch (error) {
      console.log(`Could not load existing asset mappings: ${error.message}`);
    }

    // Load failed assets list
    try {
      if (fs.existsSync(this.failedAssetsFile)) {
        const data = fs.readFileSync(this.failedAssetsFile, 'utf8');
        this.failedAssets = new Set(JSON.parse(data));
        console.log(`Loaded failed assets list: ${this.failedAssets.size} assets`);
      }
    } catch (error) {
      console.log(`Could not load failed assets list: ${error.message}`);
    }
  }

  /**
   * Save data frequently
   */
  saveData() {
    try {
      // Save price data
      fs.writeFileSync(this.outputFile, JSON.stringify(this.priceData, null, 2));
      
      // Save asset mappings
      const mappingsData = Object.fromEntries(this.assetMappings);
      fs.writeFileSync(this.mappingsFile, JSON.stringify(mappingsData, null, 2));
      
      // Save failed assets
      const failedAssetsArray = Array.from(this.failedAssets);
      fs.writeFileSync(this.failedAssetsFile, JSON.stringify(failedAssetsArray, null, 2));
      
      this.progress.lastSaveTime = new Date().toISOString();
      console.log(`Data saved at ${this.progress.lastSaveTime}`);
      
    } catch (error) {
      console.error(`Failed to save data: ${error.message}`);
    }
  }

  /**
   * Load the feeflow analysis data
   */
  loadFeeflowAnalysis(filename = 'feeflow-analysis.json') {
    try {
      console.log(`Loading feeflow analysis from: ${filename}`);
      const data = fs.readFileSync(filename, 'utf8');
      console.log(`File size: ${data.length} characters`);
      const analysis = JSON.parse(data);
      console.log(`Parsed successfully. Keys: ${Object.keys(analysis).join(', ')}`);
      if (analysis.chains) {
        console.log(`Chains found: ${Object.keys(analysis.chains).length}`);
      }
      if (analysis.global) {
        console.log(`Global data: ${analysis.global.totalChains} chains, ${analysis.global.totalAuctions} auctions`);
      }
      return analysis;
    } catch (error) {
      console.error(`Error in loadFeeflowAnalysis: ${error.message}`);
      throw new Error(`Failed to load feeflow analysis: ${error.message}`);
    }
  }

  /**
   * Extract all assets and their timestamps from the analysis
   */
  extractAllAssets(analysis) {
    console.log('\n=== Extracting All Assets and Timestamps ===');
    
    const allAssets = new Map(); // assetKey -> { chainId, address, vault, chainName, timestamps: Set }
    
    for (const [chainId, chainData] of Object.entries(analysis.chains)) {
      console.log(`Processing chain ${chainId} (${this.priceFetcher.getChainName(chainId)})...`);
      
      for (const auction of chainData.auctions) {
        for (const asset of auction.assets) {
          const assetKey = `${chainId}:${asset.underlyingAsset}`;
          
          if (!allAssets.has(assetKey)) {
            allAssets.set(assetKey, {
              chainId,
              address: asset.underlyingAsset,
              vault: asset.vault,
              chainName: this.priceFetcher.getChainName(chainId),
              timestamps: new Set(),
              frequency: 0
            });
          }
          
          // Add timestamp and increment frequency
          allAssets.get(assetKey).timestamps.add(auction.timestamp);
          allAssets.get(assetKey).frequency++;
        }
      }
    }
    
    // Sort by frequency (most common first)
    const sortedAssets = Array.from(allAssets.entries())
      .sort((a, b) => b[1].frequency - a[1].frequency);
    
    // Clear and repopulate with sorted assets
    allAssets.clear();
    for (const [key, asset] of sortedAssets) {
      allAssets.set(key, asset);
    }
    
    console.log(`\nFound ${allAssets.size} unique assets`);
    
    // Display top assets
    console.log('\nTop Assets by Frequency:');
    let count = 0;
    for (const [key, asset] of allAssets) {
      if (count >= 10) break;
      console.log(`  ${key} (${asset.chainName}): ${asset.frequency} auctions, ${asset.timestamps.size} unique timestamps`);
      count++;
    }
    
    return allAssets;
  }

  /**
   * Collect EUL prices for all auction timestamps
   */
  async collectEULPrices(analysis) {
    console.log('\n=== Collecting EUL Prices ===');
    
    // Extract all unique timestamps from all auctions across all chains
    const allTimestamps = new Set();
    Object.entries(analysis.chains).forEach(([chainId, chain]) => {
      chain.auctions.forEach(auction => {
        allTimestamps.add(auction.timestamp);
      });
    });
    
    const timestamps = Array.from(allTimestamps).sort((a, b) => a - b);
    console.log(`Found ${timestamps.length} unique auction timestamps for EUL price collection`);
    
    // Initialize EUL asset in price data if not exists
    const eulAssetKey = '1:0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b'; // EUL on Ethereum
    if (!this.priceData.assets[eulAssetKey]) {
      this.priceData.assets[eulAssetKey] = {
        chainId: '1',
        address: '0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b',
        chainName: 'Ethereum',
        symbol: 'EUL',
        decimals: 18,
        prices: {}
      };
    }
    
    const existingEULTimestamps = Object.keys(this.priceData.assets[eulAssetKey].prices || {}).map(Number);
    const missingEULTimestamps = timestamps.filter(ts => !existingEULTimestamps.includes(ts));
    
    if (missingEULTimestamps.length === 0) {
      console.log('✅ EUL prices already collected for all timestamps');
      return;
    }
    
    console.log(`Collecting EUL prices for ${missingEULTimestamps.length} missing timestamps...`);
    
    let successCount = 0;
    let failCount = 0;
    
    for (let i = 0; i < missingEULTimestamps.length; i++) {
      const timestamp = missingEULTimestamps[i];
      
      try {
        // Try to fetch EUL price from DefiLlama first
        let priceData = await this.priceFetcher.getHistoricalPrice(
          '1', // Ethereum chain ID
          '0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b', // EUL contract address
          timestamp
        );
        
        // If DefiLlama fails, try CoinGecko
        if (!priceData) {
          try {
            priceData = await this.priceFetcher.getHistoricalPrice(
              'coingecko', // Use CoinGecko
              'euler', // EUL token ID on CoinGecko
              timestamp
            );
          } catch (coingeckoError) {
            console.log(`    CoinGecko also failed: ${coingeckoError.message}`);
          }
        }
        
        if (priceData) {
          this.priceData.assets[eulAssetKey].prices[timestamp] = priceData.price;
          
          // Update metadata if not present
          if (!this.priceData.assets[eulAssetKey].decimals) {
            this.priceData.assets[eulAssetKey].decimals = priceData.decimals;
          }
          if (!this.priceData.assets[eulAssetKey].symbol) {
            this.priceData.assets[eulAssetKey].symbol = priceData.symbol;
          }
          
          successCount++;
          
          if (successCount % 10 === 0) {
            console.log(`  Progress: ${successCount}/${missingEULTimestamps.length} EUL prices collected`);
            this.saveData();
          }
        } else {
          failCount++;
          console.log(`  ✗ ${new Date(timestamp * 1000).toISOString()}: Failed to fetch EUL price`);
        }
      } catch (error) {
        failCount++;
        console.log(`  ✗ ${new Date(timestamp * 1000).toISOString()}: ${error.message}`);
      }
      
      // Rate limiting delay
      await new Promise(resolve => setTimeout(resolve, this.priceFetcher.rateLimitDelay));
    }
    
    console.log(`\n✅ EUL price collection complete:`);
    console.log(`  Success: ${successCount}/${missingEULTimestamps.length} timestamps`);
    console.log(`  Failed: ${failCount}/${missingEULTimestamps.length} timestamps`);
    console.log(`  Total EUL prices: ${Object.keys(this.priceData.assets[eulAssetKey].prices).length}`);
    
    // Save data after EUL collection
    this.saveData();
  }

  /**
   * Check if an asset needs processing (incomplete coverage or not processed)
   */
  needsProcessing(assetKey, asset) {
    console.log(`\n🔍 needsProcessing called for ${assetKey}`);
    console.log(`  this.priceData.assets exists: ${!!this.priceData.assets}`);
    console.log(`  this.priceData.assets type: ${typeof this.priceData.assets}`);
    if (this.priceData.assets) {
      console.log(`  this.priceData.assets keys: ${Object.keys(this.priceData.assets).length}`);
      console.log(`  Looking for key: ${assetKey}`);
      console.log(`  Key exists: ${assetKey in this.priceData.assets}`);
    }
    
    // If asset doesn't exist in price data, check if it's mapped to an existing asset
    if (!this.priceData.assets || !this.priceData.assets[assetKey]) {
      // Check if this asset is mapped to an existing asset with complete coverage
      for (const [mappingKey, mapping] of this.assetMappings) {
        if (mapping.baseAsset === assetKey) {
          // This asset is a base asset, check if it has complete coverage
          const baseAsset = this.priceData.assets[mapping.baseAsset];
          if (baseAsset) {
            const requiredTimestamps = Array.from(asset.timestamps);
            const existingTimestamps = Object.keys(baseAsset.prices || {}).map(Number);
            const missingTimestamps = requiredTimestamps.filter(ts => !existingTimestamps.includes(ts));
            
            if (missingTimestamps.length === 0) {
              console.log(`\n✅ ${assetKey} is mapped as base asset with complete coverage`);
              return false;
            }
          }
        }
        
        // Check if this asset is an equivalent in an existing mapping
        const isEquivalent = mapping.equivalents.find(eq => eq.assetKey === assetKey);
        if (isEquivalent) {
          // This asset is mapped to a base asset, check if the base asset has complete coverage
          const baseAsset = this.priceData.assets[mapping.baseAsset];
          if (baseAsset) {
            const requiredTimestamps = Array.from(asset.timestamps);
            const existingTimestamps = Object.keys(baseAsset.prices || {}).map(Number);
            const missingTimestamps = requiredTimestamps.filter(ts => !existingTimestamps.includes(ts));
            
            if (missingTimestamps.length === 0) {
              console.log(`\n✅ ${assetKey} is mapped to ${mapping.baseAsset} with complete coverage`);
              return false;
            }
          }
        }
      }
      
      return true;
    }
    
    const existingAsset = this.priceData.assets[assetKey];
    const requiredTimestamps = Array.from(asset.timestamps);
    
    // Debug logging to see what's happening
    console.log(`\n🔍 Coverage check for ${assetKey}:`);
    console.log(`  Asset exists in price data: ${!!existingAsset}`);
    if (existingAsset) {
      console.log(`  Asset has prices: ${!!existingAsset.prices}`);
      console.log(`  Asset has metadata: ${!!existingAsset.metadata}`);
      console.log(`  Asset symbol: ${existingAsset.symbol}`);
      console.log(`  Price keys: ${Object.keys(existingAsset.prices || {}).length}`);
      console.log(`  First few price keys: ${Object.keys(existingAsset.prices || {}).slice(0, 5)}`);
    }
    
    const existingTimestamps = Object.keys(existingAsset?.prices || {}).map(Number);
    
    console.log(`  Required timestamps: ${requiredTimestamps.length}`);
    console.log(`  Existing timestamps: ${existingTimestamps.length}`);
    console.log(`  Required: ${requiredTimestamps.slice(0, 5).map(ts => new Date(ts * 1000).toISOString().substring(0, 10))}...`);
    console.log(`  Existing: ${existingTimestamps.slice(0, 5).map(ts => new Date(ts * 1000).toISOString().substring(0, 10))}...`);
    
    // Check if we have prices for all required timestamps for THIS asset on THIS chain
    const missingTimestamps = requiredTimestamps.filter(ts => !existingTimestamps.includes(ts));
    
    if (missingTimestamps.length > 0) {
      console.log(`\n🔄 ${assetKey} needs processing - missing ${missingTimestamps.length}/${requiredTimestamps.length} timestamps`);
      
      // Check if we can re-fetch missing timestamps using existing metadata
      if (existingAsset.metadata && existingAsset.metadata.source) {
        console.log(`  📥 Asset has metadata: ${existingAsset.metadata.source}`);
        return 'refetch'; // Special return value to indicate re-fetching
      }
      
      // For assets without metadata but with existing prices, try to re-fetch using common identifiers
      if (existingAsset.symbol) {
        console.log(`  📥 Asset has symbol: ${existingAsset.symbol}, attempting smart re-fetch`);
        return 'refetch';
      }
      
      return true;
    }
    
    return false;
  }

  /**
   * Get chain name from chain ID
   */
  getChainName(chainId) {
    const chainNames = {
      '1': 'Ethereum',
      '56': 'BSC',
      '130': 'Unichain',
      '146': 'Sonic',
      '239': 'TAC',
      '1923': 'Swellchain',
      '8453': 'Base',
      '42161': 'Arbitrum',
      '43114': 'Avalanche',
      '59144': 'Linea',
      '60808': 'BOB',
      '80094': 'Berachain'
    };
    return chainNames[chainId] || `Chain ${chainId}`;
  }

  /**
   * Determine DefiLlama identifier for an asset based on its symbol and chain
   */
  async determineDefiLlamaId(assetKey, assetData) {
    // Try to determine DefiLlama identifier based on chain and symbol
    const [chainId, address] = assetKey.split(':');
    const chainName = this.getChainName(chainId).toLowerCase();
    const symbol = assetData.symbol?.toLowerCase();
    
    // Common mappings
    const commonMappings = {
      'usdc': 'coingecko:usd-coin',
      'usdt': 'coingecko:tether',
      'weth': 'coingecko:weth',
      'wbtc': 'coingecko:wrapped-bitcoin',
      'dai': 'coingecko:dai',
      'ton': 'ton:EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c',
      'matic': 'coingecko:matic-network',
      'avax': 'coingecko:avalanche-2',
      'bnb': 'coingecko:bnb',
      'link': 'coingecko:chainlink',
      'uni': 'coingecko:uniswap',
      'aave': 'coingecko:aave',
      'comp': 'coingecko:compound-governance-token',
      'sushi': 'coingecko:sushi',
      'crv': 'coingecko:curve-dao-token',
      'yfi': 'coingecko:yearn-finance',
      '1inch': 'coingecko:1inch',
      'bal': 'coingecko:balancer',
      'snx': 'coingecko:havven',
      'ren': 'coingecko:republic-protocol'
    };
    
    if (symbol && commonMappings[symbol]) {
      return commonMappings[symbol];
    }
    
    // For native tokens, use coingecko format
    if (symbol === 'wavax' && chainId === '43114') {
      return 'coingecko:avalanche-2';
    }
    if (symbol === 'wbnb' && chainId === '56') {
      return 'coingecko:bnb';
    }
    if (symbol === 'wmatic' && chainId === '137') {
      return 'coingecko:matic-network';
    }
    
    // For other tokens, try chain:address format
    return `${chainName}:${address}`;
  }

  /**
   * Re-fetch missing timestamps for an existing asset using its metadata
   */
  async refetchMissingTimestamps(assetKey, asset) {
    console.log(`\n=== Re-fetching Missing Timestamps for ${assetKey} ===`);
    
    const existingAsset = this.priceData.assets[assetKey];
    const requiredTimestamps = Array.from(asset.timestamps);
    const existingTimestamps = Object.keys(existingAsset.prices || {}).map(Number);
    const missingTimestamps = requiredTimestamps.filter(ts => !existingTimestamps.includes(ts));
    
    console.log(`Missing ${missingTimestamps.length} timestamps out of ${requiredTimestamps.length} total`);
    
    if (!existingAsset.metadata || !existingAsset.metadata.source) {
      // Try to determine DefiLlama identifier from symbol for common assets
      console.log(`📥 No metadata found, attempting to determine DefiLlama identifier from symbol: ${existingAsset.symbol}`);
      
      const defiLlamaId = await this.determineDefiLlamaId(assetKey, existingAsset);
      if (defiLlamaId) {
        console.log(`✅ Determined DefiLlama identifier: ${defiLlamaId}`);
        // Create temporary metadata for this re-fetch
        existingAsset.metadata = {
          source: 'defillama',
          defiLlamaId: defiLlamaId,
          autoDetected: true,
          detectedAt: new Date().toISOString()
        };
      } else {
        console.log(`❌ Cannot determine DefiLlama identifier for ${assetKey}, cannot re-fetch`);
        return false;
      }
    }
    
    const metadata = existingAsset.metadata;
    let successCount = 0;
    
    if (metadata.source === 'defillama' && metadata.defiLlamaId) {
      console.log(`📥 Re-fetching from DefiLlama using: ${metadata.defiLlamaId}`);
      
      for (const timestamp of missingTimestamps) {
        try {
          const url = `https://coins.llama.fi/prices/historical/${timestamp}/${metadata.defiLlamaId}`;
          const response = await fetch(url);
          
          if (response.ok) {
            const data = await response.json();
            const priceData = data.coins[metadata.defiLlamaId];
            
            if (priceData && priceData.price) {
              existingAsset.prices[timestamp] = priceData.price;
              successCount++;
              console.log(`  ✅ ${new Date(timestamp * 1000).toISOString().substring(0, 10)}: $${priceData.price}`);
            }
          }
          
          // Rate limiting
          await new Promise(resolve => setTimeout(resolve, 100));
          
        } catch (error) {
          console.log(`  ❌ Failed to fetch ${new Date(timestamp * 1000).toISOString().substring(0, 10)}: ${error.message}`);
        }
      }
      
      if (successCount > 0) {
        // Update metadata
        existingAsset.metadata.lastUpdated = new Date().toISOString();
        existingAsset.metadata.lastRefetch = {
          timestamp: new Date().toISOString(),
          fetchedCount: successCount,
          totalMissing: missingTimestamps.length
        };
        
        console.log(`✅ Successfully re-fetched ${successCount}/${missingTimestamps.length} missing timestamps`);
        return true;
      }
      
    } else if (metadata.source === 'manual') {
      console.log(`⚠️  Manual hardcoded asset - cannot automatically re-fetch`);
      console.log(`   Please use manual mapping assistant for new timestamps`);
      return false;
      
    } else if (metadata.source === 'cross-chain') {
      console.log(`🔄 Cross-chain mapped asset - checking base asset coverage`);
      // This will be handled by the mapping logic
      return false;
      
    } else {
      console.log(`❌ Unknown source: ${metadata.source}`);
      return false;
    }
    
    return false;
  }

  /**
   * Test if an asset has price data available
   */
  async testAssetPrice(assetKey, asset) {
    console.log(`\n=== Testing Asset: ${assetKey} ===`);
    console.log(`Chain: ${asset.chainName}, Frequency: ${asset.frequency}, Timestamps: ${asset.timestamps.size}`);
    
    // Try to get a price for the first timestamp
    const firstTimestamp = Array.from(asset.timestamps)[0];
    console.log(`Testing with timestamp: ${new Date(firstTimestamp * 1000).toISOString()}`);
    
    try {
      let priceData;
      
      if (asset.address === '0x0000000000000000000000000000000000000000' || 
          asset.address === '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE') {
        // Native token
        const chainName = asset.chainName.toLowerCase();
        priceData = await this.priceFetcher.getHistoricalPrice(
          chainName === 'ethereum' ? '1' : chainName,
          '0x0000000000000000000000000000000000000000',
          firstTimestamp
        );
      } else {
        // ERC20 token
        priceData = await this.priceFetcher.getHistoricalPrice(
          asset.chainId,
          asset.address,
          firstTimestamp
        );
      }
      
      if (priceData) {
        console.log(`✅ SUCCESS: ${priceData.symbol} at $${priceData.price}`);
        return true;
      } else {
        console.log(`❌ FAILED: No price data returned`);
        
        // Try ERC4626 vault detection as fallback
        console.log(`🔄 Attempting ERC4626 vault detection...`);
        const vaultInfo = await this.detectERC4626Vault(assetKey, asset);
        if (vaultInfo) {
          console.log(`✅ Detected ERC4626 vault: ${vaultInfo.symbol} (${vaultInfo.underlyingAsset})`);
          return 'vault';
        }
        
        return false;
      }
      
    } catch (error) {
      console.log(`❌ FAILED: ${error.message}`);
      
      // Try ERC4626 vault detection as fallback
      console.log(`🔄 Attempting ERC4626 vault detection...`);
      const vaultInfo = await this.detectERC4626Vault(assetKey, asset);
      if (vaultInfo) {
        console.log(`✅ Detected ERC4626 vault: ${vaultInfo.symbol} (${vaultInfo.underlyingAsset})`);
        return 'vault';
      }
      
      return false;
    }
  }

  /**
   * Detect if an asset is an ERC4626 vault and get its underlying asset
   */
  async detectERC4626Vault(assetKey, asset) {
    try {
      console.log(`  🔍 Checking if ${assetKey} is an ERC4626 vault...`);
      
      // Load EVault ABI from euler-interfaces (same pattern as feeflow-analyzer.js)
      const erc4626Abi = JSON.parse(fs.readFileSync(path.join(__dirname, '../../../../euler-interfaces/abis/EVault.json'), 'utf8'));
      
      // Get RPC URL for the chain
      const rpcUrl = this.getRpcUrl(asset.chainId);
      if (!rpcUrl) {
        console.log(`    ⚠️  No RPC URL configured for chain ${asset.chainId}`);
        return null;
      }
      
      // Create viem client (same pattern as feeflow-analyzer.js)
      const client = createPublicClient({
        chain: { id: parseInt(asset.chainId) },
        transport: http(rpcUrl)
      });
      
      // Try to call asset() function with timeout
      const underlyingAsset = await Promise.race([
        client.readContract({
          address: asset.address,
          abi: erc4626Abi,
          functionName: 'asset'
        }),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Timeout after 10 seconds')), 10000)
        )
      ]);
      
      if (!underlyingAsset || underlyingAsset === '0x0000000000000000000000000000000000000000') {
        console.log(`    ❌ Not an ERC4626 vault or invalid underlying asset`);
        return null;
      }
      
      // Try to call convertToAssets function with timeout
      try {
        await Promise.race([
          client.readContract({
            address: asset.address,
            abi: erc4626Abi,
            functionName: 'convertToAssets',
            args: [1n] // 1 share
          }),
          new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Timeout after 10 seconds')), 10000)
          )
        ]);
      } catch (error) {
        console.log(`    ❌ convertToAssets function failed: ${error.message}`);
        return null;
      }
      
      // Get vault metadata with timeout
      const [symbol, decimals] = await Promise.all([
        Promise.race([
          client.readContract({
            address: asset.address,
            abi: erc4626Abi,
            functionName: 'symbol'
          }),
          new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Timeout after 10 seconds')), 10000)
          )
        ]),
        Promise.race([
          client.readContract({
            address: asset.address,
            abi: erc4626Abi,
            functionName: 'decimals'
          }),
          new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Timeout after 10 seconds')), 10000)
          )
        ])
      ]);
      
      console.log(`    ✅ ERC4626 vault detected!`);
      console.log(`      Underlying asset: ${underlyingAsset}`);
      console.log(`      Vault symbol: ${symbol}`);
      console.log(`      Vault decimals: ${decimals}`);
      
      return {
        type: 'ERC4626',
        underlyingAsset: underlyingAsset,
        symbol: symbol,
        decimals: decimals,
        client: client,
        abi: erc4626Abi
      };
      
    } catch (error) {
      console.log(`    ❌ ERC4626 detection failed: ${error.message}`);
      return null;
    }
  }

  /**
   * Discover available chains from environment variables
   * Follows the same pattern as feeflow-analyzer.js
   */
  discoverChains() {
    const chains = {};
    const envVars = Object.keys(process.env);
    
    for (const envVar of envVars) {
      const match = envVar.match(/^DEPLOYMENT_RPC_URL_(\d+)$/);
      if (match) {
        const chainId = parseInt(match[1]);
        chains[chainId] = {
          chainId,
          rpc: process.env[envVar]
        };
      }
    }
    
    return chains;
  }

  /**
   * Get RPC URL for a specific chain
   * Follows the same pattern as feeflow-analyzer.js
   */
  getRpcUrl(chainId) {
    // Look for DEPLOYMENT_RPC_URL_{chainId} environment variable
    const envVar = `DEPLOYMENT_RPC_URL_${chainId}`;
    const rpcUrl = process.env[envVar];
    
    if (rpcUrl) {
      return rpcUrl;
    }
    
    console.log(`    ⚠️  No env var ${envVar}, using fallback`);
    
    // Fallback to hardcoded URLs for common chains
    const fallbackUrls = {
      '1': 'https://eth-mainnet.g.alchemy.com/v2/demo',
      '56': 'https://bsc-dataseed.binance.org/',
      '130': 'https://rpc.unichain.world',
      '146': 'https://mainnet.sonic.oasys.games',
      '239': 'https://rpc.tacchain.com',
      '1923': 'https://rpc.swellchain.io',
      '8453': 'https://mainnet.base.org',
      '42161': 'https://arb1.arbitrum.io/rpc',
      '43114': 'https://api.avax.network/ext/bc/C/rpc',
      '59144': 'https://rpc.linea.build',
      '60808': 'https://mainnet.bobchain.com',
      '80094': 'https://artio.rpc.berachain.com'
    };
    
    return fallbackUrls[chainId];
  }

  /**
   * Process a single asset completely
   */
  async processAsset(assetKey, asset) {
    console.log(`\n=== Processing Asset: ${assetKey} ===`);
    
    // Initialize asset in price data
    if (!this.priceData.assets) this.priceData.assets = {};
    if (!this.priceData.assets[assetKey]) {
      this.priceData.assets[assetKey] = {
        chainId: asset.chainId,
        address: asset.address,
        chainName: asset.chainName,
        prices: {}
      };
    }
    
    // Process only the timestamps where THIS asset on THIS chain appears
    const timestamps = Array.from(asset.timestamps).sort((a, b) => a - b);
    const existingTimestamps = Object.keys(this.priceData.assets[assetKey].prices || {}).map(Number);
    const missingTimestamps = timestamps.filter(ts => !existingTimestamps.includes(ts));
    
    console.log(`Timestamps for this asset: ${timestamps.length}`);
    console.log(`Already have: ${existingTimestamps.length}`);
    console.log(`Already have: ${existingTimestamps.length}`);
    console.log(`Missing: ${missingTimestamps.length}`);
    console.log(`Fetching prices for ${missingTimestamps.length} missing timestamps...`);
    
    let successCount = 0;
    let failCount = 0;
    let skippedCount = 0;
    
    for (let i = 0; i < missingTimestamps.length; i++) {
      const timestamp = missingTimestamps[i];
      
      // Double-check we don't already have this timestamp (shouldn't happen, but safety check)
      if (this.priceData.assets[assetKey].prices[timestamp]) {
        skippedCount++;
        continue;
      }
      
      try {
        let priceData;
        
        if (asset.address === '0x0000000000000000000000000000000000000000' || 
            asset.address === '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE') {
          // Native token
          const chainName = asset.chainName.toLowerCase();
          priceData = await this.priceFetcher.getHistoricalPrice(
            chainName === 'ethereum' ? '1' : chainName,
            '0x0000000000000000000000000000000000000000',
            timestamp
          );
        } else {
          // ERC20 token
          priceData = await this.priceFetcher.getHistoricalPrice(
            asset.chainId,
            asset.address,
            timestamp
          );
        }
        
        if (priceData) {
          // Store only the price value, not the full object
          this.priceData.assets[assetKey].prices[timestamp] = priceData.price;
          
          // Store metadata (decimals, symbol) only once if not already present
          if (!this.priceData.assets[assetKey].decimals) {
            this.priceData.assets[assetKey].decimals = priceData.decimals;
          }
          if (!this.priceData.assets[assetKey].symbol) {
            this.priceData.assets[assetKey].symbol = priceData.symbol;
          }
          
          successCount++;
          
          if (successCount % 10 === 0) {
            console.log(`  Progress: ${successCount}/${missingTimestamps.length} prices collected`);
            // Save data every 10 successful prices
            this.saveData();
          }
        } else {
          failCount++;
        }
        
      } catch (error) {
        failCount++;
        console.log(`  ✗ ${new Date(timestamp * 1000).toISOString()}: ${error.message}`);
      }
      
      // Rate limiting delay
      await new Promise(resolve => setTimeout(resolve, this.priceFetcher.rateLimitDelay));
    }
    
    console.log(`\n✅ Asset ${assetKey} complete:`);
    console.log(`  Success: ${successCount}/${missingTimestamps.length} missing timestamps`);
    console.log(`  Skipped: ${skippedCount}/${missingTimestamps.length} (already had prices)`);
    console.log(`  Failed: ${failCount}/${missingTimestamps.length}`);
    console.log(`  Total coverage: ${existingTimestamps.length + successCount}/${timestamps.length} (${((existingTimestamps.length + successCount) / timestamps.length * 100).toFixed(1)}%)`);
    
    // Check if we have incomplete coverage and add to failed assets if needed
    const finalCoverage = existingTimestamps.length + successCount;
    const requiredCoverage = timestamps.length;
    
    if (finalCoverage < requiredCoverage) {
      const missingCount = requiredCoverage - finalCoverage;
      console.log(`⚠️  Asset ${assetKey} has incomplete coverage: ${finalCoverage}/${requiredCoverage} (${missingCount} missing timestamps)`);
      console.log(`   Adding to failed assets for manual handling`);
      this.failedAssets.add(assetKey);
    } else {
      console.log(`✅ Asset ${assetKey} has complete coverage: ${finalCoverage}/${requiredCoverage}`);
    }
    
    // Save data after each asset
    this.saveData();
    
    return successCount > 0 || skippedCount > 0;
  }

  /**
   * Process an ERC4626 vault by calculating prices from underlying asset
   */
  async processERC4626Vault(assetKey, asset, vaultInfo) {
    console.log(`\n=== Processing ERC4626 Vault: ${assetKey} ===`);
    console.log(`Vault: ${vaultInfo.symbol} (${vaultInfo.decimals} decimals)`);
    console.log(`Underlying: ${vaultInfo.underlyingAsset}`);
    
    // Create underlying asset key and check if we need to collect its prices
    const underlyingAssetKey = `${asset.chainId}:${vaultInfo.underlyingAsset}`;
    let underlyingAsset = this.priceData.assets[underlyingAssetKey];
    
    if (!underlyingAsset) {
      console.log(`📥 Underlying asset ${underlyingAssetKey} not found, collecting prices first...`);
      
      // Initialize underlying asset in price data
      this.priceData.assets[underlyingAssetKey] = {
        chainId: asset.chainId,
        address: vaultInfo.underlyingAsset,
        chainName: asset.chainName,
        prices: {}
      };
      underlyingAsset = this.priceData.assets[underlyingAssetKey];
      
      // Collect prices for the underlying asset at all required timestamps
      const underlyingTimestamps = Array.from(asset.timestamps).sort((a, b) => a - b);
      console.log(`  Collecting ${underlyingTimestamps.length} underlying asset prices...`);
      
      for (const timestamp of underlyingTimestamps) {
        try {
          let priceData;
          
          if (vaultInfo.underlyingAsset === '0x0000000000000000000000000000000000000000' || 
              vaultInfo.underlyingAsset === '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE') {
            // Native token
            const chainName = asset.chainName.toLowerCase();
            priceData = await this.priceFetcher.getHistoricalPrice(
              chainName === 'ethereum' ? '1' : chainName,
              '0x0000000000000000000000000000000000000000',
              timestamp
            );
          } else {
            // ERC20 token
            priceData = await this.priceFetcher.getHistoricalPrice(
              asset.chainId,
              vaultInfo.underlyingAsset,
              timestamp
            );
          }
          
          if (priceData) {
            underlyingAsset.prices[timestamp] = priceData.price;
            if (!underlyingAsset.decimals) underlyingAsset.decimals = priceData.decimals;
            if (!underlyingAsset.symbol) underlyingAsset.symbol = priceData.symbol;
          } else {
            console.log(`    ⚠️  Failed to get underlying price for ${new Date(timestamp * 1000).toISOString()}`);
          }
        } catch (error) {
          console.log(`    ❌ Error getting underlying price for ${new Date(timestamp * 1000).toISOString()}: ${error.message}`);
        }
      }
      
      console.log(`  ✅ Collected ${Object.keys(underlyingAsset.prices).length} underlying asset prices`);
    } else {
      console.log(`✅ Found existing underlying asset: ${underlyingAsset.symbol} with ${Object.keys(underlyingAsset.prices).length} prices`);
    }
    
    // Initialize vault in price data
    if (!this.priceData.assets[assetKey]) {
      this.priceData.assets[assetKey] = {
        chainId: asset.chainId,
        address: asset.address,
        chainName: asset.chainName,
        decimals: vaultInfo.decimals,
        symbol: vaultInfo.symbol,
        prices: {},
        metadata: {
          type: 'ERC4626',
          underlyingAsset: underlyingAssetKey,
          calculationMethod: 'convertToAssets'
        }
      };
    }
    
    // Get timestamps where this vault appears
    const timestamps = Array.from(asset.timestamps).sort((a, b) => a - b);
    const existingTimestamps = Object.keys(this.priceData.assets[assetKey].prices || {}).map(Number);
    const missingTimestamps = timestamps.filter(ts => !existingTimestamps.includes(ts));
    
    console.log(`Timestamps for vault: ${timestamps.length}`);
    console.log(`Already have: ${existingTimestamps.length}`);
    console.log(`Missing: ${missingTimestamps.length}`);
    console.log(`Calculating vault prices for ${missingTimestamps.length} missing timestamps...`);
    
    let successCount = 0;
    let failCount = 0;
    let skippedCount = 0;
    
    for (let i = 0; i < missingTimestamps.length; i++) {
      const timestamp = missingTimestamps[i];
      
      // Check if we already have this timestamp
      if (this.priceData.assets[assetKey].prices[timestamp]) {
        skippedCount++;
        continue;
      }
      
      try {
        // Check if we have underlying asset price for this timestamp
        if (!underlyingAsset.prices[timestamp]) {
          console.log(`  ⚠️  No underlying price for ${new Date(timestamp * 1000).toISOString()}, skipping`);
          failCount++;
          continue;
        }
        
        // Get the exchange rate at this timestamp using convertToAssets
        // Use 1 vault share in the vault's decimal system
        const oneVaultShare = 1n * (10n ** BigInt(vaultInfo.decimals)); // 1 vault share in vault decimals
        const underlyingAmount = await vaultInfo.client.readContract({
          address: asset.address,
          abi: vaultInfo.abi,
          functionName: 'convertToAssets',
          args: [oneVaultShare]
        });
        
        // Calculate exchange rate (how many underlying tokens per 1 vault share)
        // The underlyingAmount is already in the correct decimal system
        const exchangeRate = Number(underlyingAmount) / (10 ** underlyingAsset.decimals);
        
        // Validate exchange rate - should be reasonable (between 0.000001 and 1000000)
        if (exchangeRate < 0.000001 || exchangeRate > 1000000) {
          console.log(`  🚨 INVALID EXCHANGE RATE: ${exchangeRate} for ${vaultInfo.symbol}`);
          console.log(`     underlyingAmount: ${underlyingAmount}, decimals: ${underlyingAsset.decimals}`);
          console.log(`     Skipping this timestamp due to corrupted exchange rate`);
          failCount++;
          continue;
        }
        
        // Calculate vault price = underlying price × exchange rate
        const underlyingPrice = underlyingAsset.prices[timestamp];
        const vaultPrice = underlyingPrice * exchangeRate;
        
        // Validate vault price - should be reasonable (between $0.000001 and $1000000)
        if (vaultPrice < 0.000001 || vaultPrice > 1000000) {
          console.log(`  🚨 INVALID VAULT PRICE: $${vaultPrice} for ${vaultInfo.symbol}`);
          console.log(`     underlyingPrice: $${underlyingPrice}, exchangeRate: ${exchangeRate}`);
          console.log(`     Skipping this timestamp due to corrupted vault price`);
          failCount++;
          continue;
        }
        
        // Store the vault price
        this.priceData.assets[assetKey].prices[timestamp] = parseFloat(vaultPrice.toFixed(6));
        
        successCount++;
        
        if (successCount % 10 === 0) {
          console.log(`  Progress: ${successCount}/${missingTimestamps.length} prices calculated`);
          console.log(`  Latest: ${vaultInfo.symbol} = $${vaultPrice.toFixed(6)} (rate: ${exchangeRate.toFixed(6)})`);
          // Save data every 10 successful prices
          this.saveData();
        }
        
      } catch (error) {
        failCount++;
        console.log(`  ✗ ${new Date(timestamp * 1000).toISOString()}: ${error.message}`);
      }
      
      // Small delay between calls
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    console.log(`\n✅ ERC4626 Vault ${assetKey} complete:`);
    console.log(`  Success: ${successCount}/${missingTimestamps.length} prices calculated`);
    console.log(`  Skipped: ${skippedCount}/${missingTimestamps.length} (already had prices)`);
    console.log(`  Failed: ${failCount}/${missingTimestamps.length}`);
    console.log(`  Total coverage: ${existingTimestamps.length + successCount}/${timestamps.length} (${((existingTimestamps.length + successCount) / timestamps.length * 100).toFixed(1)}%)`);
    
    // Save data after processing
    this.saveData();
    
    return successCount > 0 || skippedCount > 0;
  }

  /**
   * Clean up corrupted price data
   */
  cleanupCorruptedPrices() {
    console.log('\n=== Cleaning Up Corrupted Price Data ===');
    
    let cleanedCount = 0;
    
    for (const [assetKey, asset] of Object.entries(this.priceData.assets)) {
      if (asset.prices) {
        const corruptedTimestamps = [];
        
        for (const [timestamp, price] of Object.entries(asset.prices)) {
          // Check for corrupted prices (over $1M per token)
          if (price > 1000000) {
            corruptedTimestamps.push(timestamp);
            console.log(`  🚨 Found corrupted price: ${asset.symbol || assetKey} = $${price} at ${timestamp}`);
          }
        }
        
        // Remove corrupted timestamps
        for (const timestamp of corruptedTimestamps) {
          delete asset.prices[timestamp];
          cleanedCount++;
        }
        
        if (corruptedTimestamps.length > 0) {
          console.log(`  ✅ Cleaned ${corruptedTimestamps.length} corrupted prices from ${asset.symbol || assetKey}`);
        }
      }
    }
    
    if (cleanedCount > 0) {
      console.log(`\n✅ Cleanup complete: removed ${cleanedCount} corrupted prices`);
      this.saveData();
    } else {
      console.log('\n✅ No corrupted prices found');
    }
  }

  /**
   * Find and automatically process cross-chain equivalents
   */
  async findCrossChainEquivalents(assetKey, asset, allAssets) {
    console.log(`\n=== Looking for Cross-Chain Equivalents ===`);
    
    const equivalents = [];
    const baseAddress = asset.address;
    
    // First, check if this asset is already mapped in existing mappings
    for (const [mappingKey, mapping] of this.assetMappings) {
      if (mapping.baseAsset === assetKey) {
        console.log(`  ✅ Asset ${assetKey} is already mapped as base asset in ${mappingKey}`);
        return mapping.equivalents;
      }
      
      // Check if this asset is an equivalent in an existing mapping
      const isEquivalent = mapping.equivalents.find(eq => eq.assetKey === assetKey);
      if (isEquivalent) {
        console.log(`  ✅ Asset ${assetKey} is already mapped as equivalent in ${mappingKey}`);
        return mapping.equivalents;
      }
    }
    
    // Look for assets with the same address on different chains
    for (const [otherKey, otherAsset] of allAssets) {
      if (otherKey === assetKey) continue;
      
      if (otherAsset.address === baseAddress) {
        equivalents.push({
          assetKey: otherKey,
          chainId: otherAsset.chainId,
          chainName: otherAsset.chainName
        });
        
        console.log(`  Found equivalent: ${otherKey} (${otherAsset.chainName})`);
      }
    }
    
    if (equivalents.length > 0) {
      // Create mapping
      const mappingKey = `cross-chain:${baseAddress}`;
      this.assetMappings.set(mappingKey, {
        baseAsset: assetKey,
        equivalents: equivalents,
        discoveredAt: new Date().toISOString()
      });
      
      console.log(`  Created mapping: ${mappingKey}`);
      
      // Automatically process all equivalents
      console.log(`  🔄 Auto-processing ${equivalents.length} cross-chain equivalents...`);
      await this.processCrossChainEquivalents(equivalents, allAssets);
    }
    
    return equivalents;
  }

  /**
   * Process cross-chain equivalent assets automatically
   */
  async processCrossChainEquivalents(equivalents, allAssets) {
    for (const equivalent of equivalents) {
      const assetKey = equivalent.assetKey;
      const asset = allAssets.get(assetKey);
      
      if (!asset) {
        console.log(`    ⚠️  Asset ${assetKey} not found in allAssets, skipping`);
        continue;
      }
      
      // Skip if already processed or marked as failed
      if (this.priceData.assets[assetKey] || this.failedAssets.has(assetKey)) {
        console.log(`    ⏭️  Asset ${assetKey} already processed or failed, skipping`);
        continue;
      }
      
      console.log(`    🎯 Processing cross-chain equivalent: ${assetKey}`);
      
      try {
        // Test if we can get prices
        const hasPrices = await this.testAssetPrice(assetKey, asset);
        
        if (hasPrices) {
          // Process the asset
          await this.processAsset(assetKey, asset);
          console.log(`    ✅ Successfully processed ${assetKey}`);
        } else {
          console.log(`    ❌ Cannot get prices for ${assetKey}, marking as failed`);
          this.failedAssets.add(assetKey);
        }
      } catch (error) {
        console.log(`    ❌ Error processing ${assetKey}: ${error.message}`);
        this.failedAssets.add(assetKey);
      }
      
      // Save data after each equivalent to preserve progress
      this.saveData();
    }
  }

  /**
   * Main execution method
   */
  async run() {
    try {
      console.log('=== Asset-by-Asset Price Collector ===\n');
      
      // Discover available chains
      const availableChains = this.discoverChains();
      console.log('Available chains with RPC URLs:');
      Object.entries(availableChains).forEach(([id, chain]) => {
        console.log(`  ${id}: ${chain.rpc ? 'RPC configured' : 'No RPC'}`);
      });
      console.log('');
      
      // Load existing data
      this.loadExistingData();
      
      // Load existing price cache if available
      this.priceFetcher.loadCache('asset-cache.json');
      
      // Load feeflow analysis
      this.analysis = this.loadFeeflowAnalysis();
      
      // Extract all assets
      const allAssets = this.extractAllAssets(this.analysis);
      
      // Collect EUL prices for all auction timestamps first
      await this.collectEULPrices(this.analysis);
      
      // If target asset specified, process only that one
      if (this.targetAsset) {
        if (allAssets.has(this.targetAsset)) {
          const asset = allAssets.get(this.targetAsset);
          
          // Test if we can get prices
          const hasPrices = await this.testAssetPrice(this.targetAsset, asset);
          
          if (hasPrices === true) {
            // Process the asset normally
            await this.processAsset(this.targetAsset, asset);
            
            // Look for cross-chain equivalents
            await this.findCrossChainEquivalents(this.targetAsset, asset, allAssets);
            
            console.log(`\n✅ Completed processing ${this.targetAsset}`);
          } else if (hasPrices === 'vault') {
            // Process as ERC4626 vault
            const vaultInfo = await this.detectERC4626Vault(this.targetAsset, asset);
            if (vaultInfo) {
              await this.processERC4626Vault(this.targetAsset, asset, vaultInfo);
              console.log(`\n✅ Completed processing ERC4626 vault ${this.targetAsset}`);
            } else {
              console.log(`\n❌ Failed to process ${this.targetAsset} as vault, marking as failed`);
              this.failedAssets.add(this.targetAsset);
              this.saveData();
            }
          } else {
            console.log(`\n❌ Cannot get prices for ${this.targetAsset}, skipping`);
            this.failedAssets.add(this.targetAsset);
            this.saveData();
          }
        } else {
          console.log(`\n❌ Asset ${this.targetAsset} not found in analysis`);
        }
      } else {
        // Process assets one by one, starting with the most frequent
        console.log('\n=== Processing Assets Automatically ===');
        console.log('Processing all assets without user input. Press Ctrl+C to stop...');
        
        for (const [assetKey, asset] of allAssets) {
          // Check if we need to process this asset (incomplete coverage or not processed)
          const needsProcessing = this.needsProcessing(assetKey, asset);
          
          if (!needsProcessing) {
            console.log(`\n⏭️  Skipping ${assetKey} - complete coverage already exists`);
            continue;
          }
          
          if (needsProcessing === 'refetch') {
            console.log(`\n🔄 Re-fetching missing timestamps for ${assetKey}`);
            const refetchSuccess = await this.refetchMissingTimestamps(assetKey, asset);
            if (refetchSuccess) {
              console.log(`✅ Successfully re-fetched missing timestamps for ${assetKey}`);
              this.saveData();
              continue;
            } else {
              console.log(`❌ Failed to re-fetch timestamps for ${assetKey}, will process normally`);
            }
          }
          
          // Skip if marked as failed
          if (this.failedAssets.has(assetKey)) {
            console.log(`\n⏭️  Skipping ${assetKey} - marked as failed`);
            continue;
          }
          
          console.log(`\n🎯 Processing asset: ${assetKey}`);
          
          // Test if we can get prices
          const hasPrices = await this.testAssetPrice(assetKey, asset);
          
          if (hasPrices === true) {
            // Process the asset normally
            await this.processAsset(assetKey, asset);
            
            // Look for cross-chain equivalents
            await this.findCrossChainEquivalents(assetKey, asset, allAssets);
            
            console.log(`\n✅ Completed processing ${assetKey}`);
          } else if (hasPrices === 'vault') {
            // Process as ERC4626 vault
            const vaultInfo = await this.detectERC4626Vault(assetKey, asset);
            if (vaultInfo) {
              await this.processERC4626Vault(assetKey, asset, vaultInfo);
              console.log(`\n✅ Completed processing ERC4626 vault ${assetKey}`);
            } else {
              console.log(`\n❌ Failed to process ${assetKey} as vault, marking as failed`);
              this.failedAssets.add(assetKey);
              this.saveData();
            }
          } else {
            console.log(`\n❌ Cannot get prices for ${assetKey}, marking as failed`);
            this.failedAssets.add(assetKey);
            this.saveData();
          }
        }
      }
      
      console.log('\n=== Collection Complete ===');
      this.generateReport();
      
    } catch (error) {
      console.error(`\nError during collection: ${error.message}`);
      this.saveData();
      process.exit(1);
    }
  }

  /**
   * Generate a report
   */
  generateReport() {
    console.log('\n=== Collection Report ===');
    
    const totalAssets = Object.keys(this.priceData.assets || {}).length;
    const totalMappings = this.assetMappings.size;
    const totalFailed = this.failedAssets.size;
    
    console.log(`\nAssets with prices: ${totalAssets}`);
    console.log(`Cross-chain mappings: ${totalMappings}`);
    console.log(`Failed assets: ${totalFailed}`);
    
    if (totalAssets > 0) {
      let totalPrices = 0;
      for (const [assetKey, assetData] of Object.entries(this.priceData.assets)) {
        const priceCount = Object.keys(assetData.prices || {}).length;
        totalPrices += priceCount;
        console.log(`  ${assetKey}: ${priceCount} prices`);
      }
      console.log(`\nTotal prices collected: ${totalPrices}`);
    }
    
    if (totalMappings > 0) {
      console.log('\nCross-chain mappings:');
      for (const [key, mapping] of this.assetMappings) {
        console.log(`  ${key}: ${mapping.equivalents.length} equivalents`);
      }
    }
  }
}

// Export the class
module.exports = AssetByAssetCollector;

// If run directly, execute the collector
if (require.main === module) {
  // Parse command line arguments
  const args = process.argv.slice(2);
  const options = {};
  
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--asset' && i + 1 < args.length) {
      options.targetAsset = args[i + 1];
      i++;
    } else if (args[i] === '--output' && i + 1 < args.length) {
      options.outputFile = args[i + 1];
      i++;
    }
  }
  
  console.log('Usage: node asset-by-asset-collector.js [--asset "chainId:address"] [--output filename]');
  console.log('Example: node asset-by-asset-collector.js --asset "1:0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"');
  console.log('Example: node asset-by-asset-collector.js (process all assets one by one)');
  
  const collector = new AssetByAssetCollector(options);
  collector.run();
}
