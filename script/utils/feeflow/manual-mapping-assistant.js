const fs = require('fs');
const readline = require('readline');
const path = require('path');
const { createPublicClient, http } = require('viem');
require('dotenv').config({ path: path.join(__dirname, '../../../.env') });

class ManualMappingAssistant {
  constructor() {
    this.failedAssets = [];
    this.assetMappings = {};
    this.priceData = {};
    this.analysis = {};
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
  }

  loadData() {
    try {
      this.failedAssets = JSON.parse(fs.readFileSync('failed-assets.json', 'utf8'));
      this.assetMappings = JSON.parse(fs.readFileSync('asset-mappings.json', 'utf8'));
      this.priceData = JSON.parse(fs.readFileSync('feeflow-asset-prices.json', 'utf8'));
      this.analysis = JSON.parse(fs.readFileSync('feeflow-analysis.json', 'utf8'));
      
      // Discover available chains from environment variables
      this.chains = {};
      const envVars = Object.keys(process.env);
      console.log('🔍 Environment variables found:', envVars.filter(v => v.startsWith('DEPLOYMENT_RPC_URL_')));
      
      for (const envVar of envVars) {
        const match = envVar.match(/^DEPLOYMENT_RPC_URL_(\d+)$/);
        if (match) {
          const chainId = parseInt(match[1]);
          this.chains[chainId] = {
            chainId,
            rpc: process.env[envVar]
          };
          console.log(`  ✅ Found RPC for chain ${chainId}: ${process.env[envVar].substring(0, 20)}...`);
        }
      }
      
      console.log(`🔗 Discovered ${Object.keys(this.chains).length} chains:`, Object.keys(this.chains));
      
      console.log(`✅ Loaded ${this.failedAssets.length} failed assets, ${Object.keys(this.assetMappings).length} existing mappings`);
    } catch (error) {
      console.error('❌ Error loading data:', error.message);
      process.exit(1);
    }
  }

  question(prompt) {
    return new Promise((resolve) => {
      this.rl.question(prompt, resolve);
    });
  }

  async getAssetInfo(assetKey) {
    const [chainId, address] = assetKey.split(':');
    const chainName = this.getChainName(chainId);
    
    // Find timestamps where this asset appears
    const timestamps = new Set();
    if (this.analysis.chains[chainId]) {
      this.analysis.chains[chainId].auctions.forEach(auction => {
        auction.assets.forEach(asset => {
          if (asset.underlyingAsset === address) {
            timestamps.add(auction.timestamp);
          }
        });
      });
    }

    return {
      assetKey,
      chainId,
      chainName,
      address,
      timestamps: Array.from(timestamps).sort((a, b) => a - b),
      count: timestamps.size
    };
  }

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
   * Create a viem client for a specific chain
   */
  createClient(chainId, chains) {
    const chain = chains[chainId];
    if (!chain || !chain.rpc) {
      throw new Error(`No RPC URL configured for chain ${chainId}`);
    }
    
    return createPublicClient({
      chain: { id: chainId },
      transport: http(chain.rpc)
    });
  }

  async fetchAssetMetadata(assetKey) {
    try {
      const [chainId, address] = assetKey.split(':');
      
      if (!this.chains[chainId]) {
        console.log(`   ⚠️  No RPC URL configured for chain ${chainId}`);
        return null;
      }

      const client = this.createClient(chainId, this.chains);

      // Basic ERC20 ABI for symbol and decimals
      const erc20Abi = [
        { inputs: [], name: 'symbol', outputs: [{ type: 'string' }], stateMutability: 'view', type: 'function' },
        { inputs: [], name: 'decimals', outputs: [{ type: 'uint8' }], stateMutability: 'view', type: 'function' }
      ];

      const [symbol, decimals] = await Promise.all([
        client.readContract({
          address: address,
          abi: erc20Abi,
          functionName: 'symbol'
        }),
        client.readContract({
          address: address,
          abi: erc20Abi,
          functionName: 'decimals'
        })
      ]);

      return { symbol, decimals };
    } catch (error) {
      console.log(`   ⚠️  Failed to fetch metadata: ${error.message}`);
      return null;
    }
  }

  findPotentialMatches(assetKey) {
    const [chainId, address] = assetKey.split(':');
    const potentialMatches = [];

    // Look for assets with same address on different chains
    Object.keys(this.priceData.assets).forEach(existingKey => {
      const [existingChainId, existingAddress] = existingKey.split(':');
      if (existingAddress === address && existingChainId !== chainId) {
        const existingAsset = this.priceData.assets[existingKey];
        potentialMatches.push({
          assetKey: existingKey,
          chainId: existingChainId,
          chainName: this.getChainName(existingChainId),
          priceCount: Object.keys(existingAsset.prices || {}).length,
          symbol: existingAsset.symbol,
          decimals: existingAsset.decimals
        });
      }
    });

    return potentialMatches;
  }

  async processAsset(assetKey) {
    console.log(`\n🔍 Processing: ${assetKey}`);
    
    const assetInfo = await this.getAssetInfo(assetKey);
    console.log(`   Chain: ${assetInfo.chainName} (${assetInfo.chainId})`);
    console.log(`   Address: ${assetInfo.address}`);
    console.log(`   Appears in ${assetInfo.count} auctions`);
    console.log(`   Timestamps: ${assetInfo.timestamps.slice(0, 5).map(ts => new Date(ts * 1000).toISOString().substring(0, 10)).join(', ')}${assetInfo.timestamps.length > 5 ? '...' : ''}`);

    // Fetch symbol and decimals automatically
    console.log(`   🔍 Fetching asset metadata...`);
    const metadata = await this.fetchAssetMetadata(assetKey);
    if (metadata) {
      console.log(`   Symbol: ${metadata.symbol}`);
      console.log(`   Decimals: ${metadata.decimals}`);
    } else {
      console.log(`   Symbol: Unknown`);
      console.log(`   Decimals: Unknown`);
    }

    const potentialMatches = this.findPotentialMatches(assetKey);
    if (potentialMatches.length > 0) {
      console.log(`\n   🎯 Potential cross-chain matches found:`);
      potentialMatches.forEach(match => {
        console.log(`      ${match.assetKey} (${match.chainName}) - ${match.priceCount} prices, ${match.symbol || 'Unknown'}`);
      });
    }

    console.log(`\n   Options:`);
    console.log(`   1. Map to existing asset (cross-chain equivalent)`);
    console.log(`   2. Skip this asset (mark as truly failed)`);
    console.log(`   3. Manually hardcode price data`);
    console.log(`   4. Fetch prices from DefiLlama`);

    const choice = await this.question(`   Your choice (1-4): `);

    if (choice === '1') {
      if (potentialMatches.length === 0) {
        console.log(`   ❌ No potential matches found. Please provide the asset key to map to:`);
        const targetAsset = await this.question(`   Target asset key (chain:address): `);
        const success = await this.createMapping(assetKey, targetAsset);
        if (!success) {
          console.log(`   ⚠️  Mapping failed, asset will be processed again`);
        }
      } else {
        const targetAsset = await this.question(`   Target asset key to map to: `);
        const success = await this.createMapping(assetKey, targetAsset);
        if (!success) {
          console.log(`   ⚠️  Mapping failed, asset will be processed again`);
        }
      }
    } else if (choice === '2') {
      console.log(`   ⏭️  Skipping ${assetKey}`);
      // Remove skipped asset from failed assets list
      this.failedAssets = this.failedAssets.filter(asset => asset !== assetKey);
    } else if (choice === '3') {
      await this.manuallyHardcodePrice(assetKey, assetInfo, metadata);
    } else if (choice === '4') {
      await this.fetchFromDefiLlama(assetKey, assetInfo, metadata);
    }
  }

  async createMapping(sourceAsset, targetAsset) {
    if (!this.priceData.assets[targetAsset]) {
      console.log(`   ❌ Target asset ${targetAsset} not found in price data`);
      return false;
    }

    const targetAssetData = this.priceData.assets[targetAsset];
    const sourceAssetInfo = await this.getAssetInfo(sourceAsset);
    
    // Create cross-chain mapping
    const mappingKey = `cross-chain:${targetAssetData.address}`;
    
    if (!this.assetMappings[mappingKey]) {
      this.assetMappings[mappingKey] = {
        baseAsset: targetAsset,
        equivalents: []
      };
    }

    // Add source asset as equivalent
    this.assetMappings[mappingKey].equivalents.push({
      assetKey: sourceAsset,
      chainId: sourceAssetInfo.chainId,
      chainName: sourceAssetInfo.chainName
    });

    // Update price data to include the source asset
    this.priceData.assets[sourceAsset] = {
      chainId: sourceAssetInfo.chainId,
      address: sourceAssetInfo.address,
      chainName: sourceAssetInfo.chainName,
      decimals: targetAssetData.decimals,
      symbol: targetAssetData.symbol,
      prices: {},
      metadata: {
        source: 'cross-chain',
        baseAsset: targetAsset,
        mappedAt: new Date().toISOString(),
        lastUpdated: new Date().toISOString()
      }
    };

    // Copy prices for required timestamps
    let copiedCount = 0;
    const missingTimestamps = [];
    
    sourceAssetInfo.timestamps.forEach(timestamp => {
      if (targetAssetData.prices[timestamp]) {
        this.priceData.assets[sourceAsset].prices[timestamp] = targetAssetData.prices[timestamp];
        copiedCount++;
      } else {
        missingTimestamps.push(timestamp);
      }
    });

    console.log(`   ✅ Mapped ${sourceAsset} to ${targetAsset}`);
    console.log(`      Copied ${copiedCount} existing prices`);
    
    // If we have missing timestamps, try to fetch them from DefiLlama
    if (missingTimestamps.length > 0) {
      console.log(`      Missing ${missingTimestamps.length} prices, attempting to fetch from DefiLlama...`);
      
      // Try to determine DefiLlama identifier from target asset
      const defiLlamaId = await this.determineDefiLlamaId(targetAsset, targetAssetData);
      
      if (defiLlamaId) {
        let fetchedCount = 0;
        for (const timestamp of missingTimestamps) {
          try {
            const url = `https://coins.llama.fi/prices/historical/${timestamp}/${defiLlamaId}`;
            const response = await fetch(url);
            
            if (response.ok) {
              const data = await response.json();
              const priceData = data.coins[defiLlamaId];
              
              if (priceData && priceData.price) {
                // Add to both target and source assets
                this.priceData.assets[targetAsset].prices[timestamp] = priceData.price;
                this.priceData.assets[sourceAsset].prices[timestamp] = priceData.price;
                fetchedCount++;
              }
            }
            
            // Rate limiting
            await new Promise(resolve => setTimeout(resolve, 100));
            
          } catch (error) {
            console.log(`         ⚠️  Failed to fetch price for ${new Date(timestamp * 1000).toISOString().substring(0, 10)}`);
          }
        }
        
        console.log(`      ✅ Fetched ${fetchedCount} additional prices from DefiLlama`);
      } else {
        console.log(`      ⚠️  Could not determine DefiLlama identifier for ${targetAsset}`);
      }
    }
    
    console.log(`      Total prices for ${sourceAsset}: ${Object.keys(this.priceData.assets[sourceAsset].prices).length}/${sourceAssetInfo.timestamps.length}`);
    
    // Remove from failed assets
    this.failedAssets = this.failedAssets.filter(asset => asset !== sourceAsset);
    return true;
  }

  async manuallyHardcodePrice(assetKey, assetInfo, metadata) {
    console.log(`\n   💰 Manual Price Hardcoding for ${assetKey}`);
    console.log(`   This asset needs prices for ${assetInfo.timestamps.length} timestamps`);
    
    // Use fetched metadata if available, otherwise prompt user
    let symbol = metadata?.symbol;
    let decimals = metadata?.decimals;
    
    if (!symbol) {
      symbol = await this.question(`   Symbol (e.g., USDC, WETH): `);
    } else {
      console.log(`   Using fetched symbol: ${symbol}`);
    }
    
    if (!decimals) {
      const decimalsInput = await this.question(`   Decimals (e.g., 6, 18): `);
      decimals = parseInt(decimalsInput);
    } else {
      console.log(`   Using fetched decimals: ${decimals}`);
    }
    
    if (isNaN(decimals)) {
      console.log(`   ❌ Invalid decimals. Aborting.`);
      return;
    }

    console.log(`\n   📅 Price Entry Options:`);
    console.log(`   1. Single price for all timestamps (e.g., stablecoin)`);
    console.log(`   2. Enter price for each timestamp individually`);
    console.log(`   3. Use a price formula (e.g., linear interpolation)`);
    
    const priceChoice = await this.question(`   Your choice (1-3): `);
    
    if (priceChoice === '1') {
      const price = parseFloat(await this.question(`   Price (e.g., 1.0 for USDC): `));
      if (isNaN(price)) {
        console.log(`   ❌ Invalid price. Aborting.`);
        return;
      }
      
      await this.createHardcodedAsset(assetKey, assetInfo, symbol, decimals, price);
      
    } else if (priceChoice === '2') {
      await this.enterIndividualPrices(assetKey, assetInfo, symbol, decimals);
      
    } else if (priceChoice === '3') {
      await this.usePriceFormula(assetKey, assetInfo, symbol, decimals);
      
    } else {
      console.log(`   ❌ Invalid choice. Aborting.`);
    }
  }

  async createHardcodedAsset(assetKey, assetInfo, symbol, decimals, price) {
    // Create the asset entry
    this.priceData.assets[assetKey] = {
      chainId: assetInfo.chainId,
      address: assetInfo.address,
      chainName: assetInfo.chainName,
      decimals: decimals,
      symbol: symbol,
      prices: {},
      metadata: {
        source: 'manual',
        method: 'hardcoded',
        price: price,
        createdAt: new Date().toISOString(),
        lastUpdated: new Date().toISOString()
      }
    };

    // Add the same price for all timestamps
    assetInfo.timestamps.forEach(timestamp => {
      this.priceData.assets[assetKey].prices[timestamp] = price;
    });

    console.log(`   ✅ Created ${assetKey} with price ${price} for all ${assetInfo.timestamps.length} timestamps`);
    console.log(`   Symbol: ${symbol}, Decimals: ${decimals}`);
    
    // Remove from failed assets
    this.failedAssets = this.failedAssets.filter(asset => asset !== assetKey);
  }

  async enterIndividualPrices(assetKey, assetInfo, symbol, decimals) {
    console.log(`\n   📝 Entering individual prices for ${assetInfo.timestamps.length} timestamps...`);
    
    // Create the asset entry
    this.priceData.assets[assetKey] = {
      chainId: assetInfo.chainId,
      address: assetInfo.address,
      chainName: assetInfo.chainName,
      decimals: decimals,
      symbol: symbol,
      prices: {}
    };

    let enteredCount = 0;
    for (const timestamp of assetInfo.timestamps) {
      const dateStr = new Date(timestamp * 1000).toISOString().substring(0, 10);
      const price = parseFloat(await this.question(`   ${dateStr} (${timestamp}): `));
      
      if (!isNaN(price)) {
        this.priceData.assets[assetKey].prices[timestamp] = price;
        enteredCount++;
      } else {
        console.log(`   ⚠️  Skipping invalid price for ${dateStr}`);
      }
    }

    console.log(`   ✅ Created ${assetKey} with ${enteredCount}/${assetInfo.timestamps.length} prices`);
    
    if (enteredCount === assetInfo.timestamps.length) {
      // Remove from failed assets only if all prices were entered
      this.failedAssets = this.failedAssets.filter(asset => asset !== assetKey);
    }
  }

  async usePriceFormula(assetKey, assetInfo, symbol, decimals) {
    console.log(`\n   📊 Price Formula Options:`);
    console.log(`   1. Linear interpolation between two prices`);
    console.log(`   2. Exponential growth/decay`);
    console.log(`   3. Custom formula`);
    
    const formulaChoice = await this.question(`   Your choice (1-3): `);
    
    if (formulaChoice === '1') {
      const startPrice = parseFloat(await this.question(`   Start price: `));
      const endPrice = parseFloat(await this.question(`   End price: `));
      
      if (isNaN(startPrice) || isNaN(endPrice)) {
        console.log(`   ❌ Invalid prices. Aborting.`);
        return;
      }
      
      await this.createLinearInterpolation(assetKey, assetInfo, symbol, decimals, startPrice, endPrice);
      
    } else if (formulaChoice === '2') {
      const startPrice = parseFloat(await this.question(`   Start price: `));
      const endPrice = parseFloat(await this.question(`   End price: `));
      const growthRate = parseFloat(await this.question(`   Growth rate per period (e.g., 0.05 for 5%): `));
      
      if (isNaN(startPrice) || isNaN(endPrice) || isNaN(growthRate)) {
        console.log(`   ❌ Invalid parameters. Aborting.`);
        return;
      }
      
      await this.createExponentialGrowth(assetKey, assetInfo, symbol, decimals, startPrice, growthRate);
      
    } else if (formulaChoice === '3') {
      console.log(`   📝 Enter custom formula (JavaScript expression using 't' for timestamp index):`);
      const formula = await this.question(`   Formula (e.g., 1.0 + t * 0.01): `);
      
      try {
        await this.createCustomFormula(assetKey, assetInfo, symbol, decimals, formula);
      } catch (error) {
        console.log(`   ❌ Invalid formula: ${error.message}`);
      }
    } else {
      console.log(`   ❌ Invalid choice. Aborting.`);
    }
  }

  async createLinearInterpolation(assetKey, assetInfo, symbol, decimals, startPrice, endPrice) {
    this.priceData.assets[assetKey] = {
      chainId: assetInfo.chainId,
      address: assetInfo.address,
      chainName: assetInfo.chainName,
      decimals: decimals,
      symbol: symbol,
      prices: {}
    };

    const totalPeriods = assetInfo.timestamps.length - 1;
    assetInfo.timestamps.forEach((timestamp, index) => {
      if (totalPeriods === 0) {
        this.priceData.assets[assetKey].prices[timestamp] = startPrice;
      } else {
        const ratio = index / totalPeriods;
        const price = startPrice + (endPrice - startPrice) * ratio;
        this.priceData.assets[assetKey].prices[timestamp] = parseFloat(price.toFixed(6));
      }
    });

    console.log(`   ✅ Created ${assetKey} with linear interpolation from ${startPrice} to ${endPrice}`);
    this.failedAssets = this.failedAssets.filter(asset => asset !== assetKey);
  }

  async createExponentialGrowth(assetKey, assetInfo, symbol, decimals, startPrice, growthRate) {
    this.priceData.assets[assetKey] = {
      chainId: assetInfo.chainId,
      address: assetInfo.address,
      chainName: assetInfo.chainName,
      decimals: decimals,
      symbol: symbol,
      prices: {}
    };

    assetInfo.timestamps.forEach((timestamp, index) => {
      const price = startPrice * Math.pow(1 + growthRate, index);
      this.priceData.assets[assetKey].prices[timestamp] = parseFloat(price.toFixed(6));
    });

    console.log(`   ✅ Created ${assetKey} with exponential growth from ${startPrice} at rate ${growthRate}`);
    this.failedAssets = this.failedAssets.filter(asset => asset !== assetKey);
  }

  async createCustomFormula(assetKey, assetInfo, symbol, decimals, formula) {
    this.priceData.assets[assetKey] = {
      chainId: assetInfo.chainId,
      address: assetInfo.address,
      chainName: assetInfo.chainName,
      decimals: decimals,
      symbol: symbol,
      prices: {}
    };

    assetInfo.timestamps.forEach((timestamp, index) => {
      const t = index;
      const price = eval(formula); // Note: eval is used here for user input - use with caution
      this.priceData.assets[assetKey].prices[timestamp] = parseFloat(price.toFixed(6));
    });

    console.log(`   ✅ Created ${assetKey} with custom formula: ${formula}`);
    this.failedAssets = this.failedAssets.filter(asset => asset !== assetKey);
  }

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

  async fetchFromDefiLlama(assetKey, assetInfo, metadata) {
    console.log(`\n   🌐 Fetching prices from DefiLlama for ${assetKey}`);
    
    let symbol = metadata?.symbol;
    let decimals = metadata?.decimals;
    
    if (!symbol) {
      symbol = await this.question(`   Enter symbol for this asset: `);
    } else {
      console.log(`   Using fetched symbol: ${symbol}`);
    }
    
    if (!decimals) {
      const decimalsInput = await this.question(`   Enter decimals for this asset: `);
      decimals = parseInt(decimalsInput);
    } else {
      console.log(`   Using fetched decimals: ${decimals}`);
    }

    // Ask for the DefiLlama identifier
    const defiLlamaId = await this.question(`   DefiLlama identifier (e.g., ton:EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c): `);
    
    if (!defiLlamaId) {
      console.log(`   ❌ No DefiLlama identifier provided. Aborting.`);
      return;
    }

    // Create the asset entry
    this.priceData.assets[assetKey] = {
      chainId: assetInfo.chainId,
      address: assetInfo.address,
      chainName: assetInfo.chainName,
      decimals: decimals,
      symbol: symbol,
      prices: {},
      metadata: {
        source: 'defillama',
        defiLlamaId: defiLlamaId,
        createdAt: new Date().toISOString(),
        lastUpdated: new Date().toISOString()
      }
    };

    console.log(`   📥 Fetching ${assetInfo.timestamps.length} historical prices...`);
    
    let successCount = 0;
    for (const timestamp of assetInfo.timestamps) {
      try {
        const url = `https://coins.llama.fi/prices/historical/${timestamp}/${defiLlamaId}`;
        const response = await fetch(url);
        
        if (!response.ok) {
          console.log(`   ⚠️  Failed to fetch price for ${new Date(timestamp * 1000).toISOString().substring(0, 10)}: ${response.status}`);
          continue;
        }
        
        const data = await response.json();
        const priceData = data.coins[defiLlamaId];
        
        if (priceData && priceData.price) {
          this.priceData.assets[assetKey].prices[timestamp] = priceData.price;
          successCount++;
        } else {
          console.log(`   ⚠️  No price data for ${new Date(timestamp * 1000).toISOString().substring(0, 10)}`);
        }
        
        // Rate limiting
        await new Promise(resolve => setTimeout(resolve, 100));
        
      } catch (error) {
        console.log(`   ❌ Error fetching price for ${new Date(timestamp * 1000).toISOString().substring(0, 10)}: ${error.message}`);
      }
    }

    console.log(`   ✅ Fetched ${successCount}/${assetInfo.timestamps.length} prices for ${assetKey}`);
    
    if (successCount > 0) {
      // Remove from failed assets
      this.failedAssets = this.failedAssets.filter(asset => asset !== assetKey);
    } else {
      console.log(`   ❌ No prices fetched. Asset remains in failed list.`);
    }
  }

  async saveData() {
    try {
      fs.writeFileSync('asset-mappings.json', JSON.stringify(this.assetMappings, null, 2));
      fs.writeFileSync('feeflow-asset-prices.json', JSON.stringify(this.priceData, null, 2));
      fs.writeFileSync('failed-assets.json', JSON.stringify(this.failedAssets, null, 2));
      console.log(`\n💾 Data saved successfully`);
    } catch (error) {
      console.error('❌ Error saving data:', error.message);
    }
  }

  async run() {
    console.log('🔧 Manual Asset Mapping Assistant');
    console.log('================================');
    
    this.loadData();
    
    console.log(`\n🔗 Available chains:`);
    Object.entries(this.chains).forEach(([id, chain]) => {
      console.log(`  ${id}: ${chain.rpc ? 'RPC configured' : 'No RPC'}`);
    });
    
    console.log(`\n📋 Processing ${this.failedAssets.length} failed assets...`);
    
    let processedCount = 0;
    while (this.failedAssets.length > 0) {
      const assetKey = this.failedAssets[0]; // Always process the first asset
      processedCount++;
      console.log(`\n${'='.repeat(60)}`);
      console.log(`Asset ${processedCount} (${this.failedAssets.length} remaining)`);
      
      await this.processAsset(assetKey);
      
      // Save after each asset to preserve progress
      await this.saveData();
      
      if (this.failedAssets.length > 0) {
        const continueChoice = await this.question(`\nContinue to next asset? (y/n): `);
        if (continueChoice.toLowerCase() !== 'y') {
          break;
        }
      }
    }
    
    console.log(`\n${'='.repeat(60)}`);
    console.log('🏁 Mapping session complete!');
    console.log(`Remaining failed assets: ${this.failedAssets.length}`);
    
    this.rl.close();
  }
}

// Run the assistant
if (require.main === module) {
  const assistant = new ManualMappingAssistant();
  assistant.run().catch(console.error);
}

module.exports = ManualMappingAssistant;
