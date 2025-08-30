#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const https = require('https');

/**
 * Price fetching utility for FeeFlow efficiency analysis
 * Uses DefiLlama's historical price API to fetch token prices at auction timestamps
 */

class PriceFetcher {
  constructor() {
    this.baseUrl = 'https://coins.llama.fi/prices/historical';
    this.cache = new Map(); // In-memory cache for price requests
    this.rateLimitDelay = 100; // ms between requests to be respectful
    this.maxRetries = 3;
  }

  /**
   * Make an HTTPS request to DefiLlama API
   */
  async makeRequest(url) {
    return new Promise((resolve, reject) => {
      const req = https.get(url, (res) => {
        let data = '';
        
        res.on('data', (chunk) => {
          data += chunk;
        });
        
        res.on('end', () => {
          if (res.statusCode === 200) {
            try {
              const jsonData = JSON.parse(data);
              resolve(jsonData);
            } catch (error) {
              reject(new Error(`Failed to parse JSON response: ${error.message}`));
            }
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${data}`));
          }
        });
      });
      
      req.on('error', (error) => {
        reject(new Error(`Request failed: ${error.message}`));
      });
      
      req.setTimeout(30000, () => {
        req.destroy();
        reject(new Error('Request timeout'));
      });
    });
  }

  /**
   * Get historical price for a token at a specific timestamp
   * @param {string} chainId - Chain ID (e.g., "1" for Ethereum)
   * @param {string} tokenAddress - Token contract address
   * @param {number} timestamp - UNIX timestamp
   * @returns {Promise<Object>} Price data with decimals, price, symbol, and timestamp
   */
  async getHistoricalPrice(chainId, tokenAddress, timestamp) {
    const cacheKey = `${chainId}:${tokenAddress}:${timestamp}`;
    
    // Check cache first
    if (this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey);
    }
    
    // Format the coins parameter for DefiLlama API
    // For native tokens, use coingecko format, otherwise use chain:address
    let coinsParam;
    if (tokenAddress === '0x0000000000000000000000000000000000000000' || 
        tokenAddress === '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE') {
      // Native token - use coingecko format
      const chainName = this.getChainName(chainId).toLowerCase();
      coinsParam = `coingecko:${chainName}`;
    } else {
      // Use chain name instead of chain ID
      const chainName = this.getChainName(chainId).toLowerCase();
      coinsParam = `${chainName}:${tokenAddress}`;
    }
    
    const url = `${this.baseUrl}/${timestamp}/${coinsParam}`;
    
    let lastError;
    
    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        console.log(`  Fetching price for ${coinsParam} at ${new Date(timestamp * 1000).toISOString()} (attempt ${attempt})`);
        
        const response = await this.makeRequest(url);
        
        if (response.coins && response.coins[coinsParam]) {
          const priceData = response.coins[coinsParam];
          
          // Cache the result
          this.cache.set(cacheKey, priceData);
          
          console.log(`    ✓ Price: $${priceData.price} (${priceData.symbol})`);
          return priceData;
        } else {
          throw new Error('No price data found in response');
        }
        
      } catch (error) {
        lastError = error;
        console.log(`    ✗ Attempt ${attempt} failed: ${error.message}`);
        
        if (attempt < this.maxRetries) {
          // Wait before retrying
          await new Promise(resolve => setTimeout(resolve, this.rateLimitDelay * 2));
        }
      }
    }
    
    throw new Error(`Failed to fetch price after ${this.maxRetries} attempts: ${lastError.message}`);
  }

  /**
   * Get historical prices for multiple tokens at the same timestamp
   * @param {Array} tokens - Array of {chainId, address} objects
   * @param {number} timestamp - UNIX timestamp
   * @returns {Promise<Object>} Map of token addresses to price data
   */
  async getHistoricalPrices(tokens, timestamp) {
    const results = {};
    const uniqueTokens = new Map();
    
    // Group tokens by chain to batch requests
    for (const token of tokens) {
      const key = `${token.chainId}:${token.address}`;
      if (!uniqueTokens.has(key)) {
        uniqueTokens.set(key, token);
      }
    }
    
    console.log(`Fetching prices for ${uniqueTokens.size} unique tokens at ${new Date(timestamp * 1000).toISOString()}`);
    
    // Process tokens with rate limiting
    for (const [key, token] of uniqueTokens) {
      try {
        const priceData = await this.getHistoricalPrice(token.chainId, token.address, timestamp);
        results[key] = priceData;
        
        // Rate limiting delay
        await new Promise(resolve => setTimeout(resolve, this.rateLimitDelay));
        
      } catch (error) {
        console.error(`Failed to fetch price for ${key}: ${error.message}`);
        results[key] = null;
      }
    }
    
    return results;
  }

  /**
   * Calculate USD value of an asset amount
   * @param {string} amount - Asset amount (as string)
   * @param {Object} priceData - Price data from DefiLlama
   * @returns {string} USD value as string
   */
  calculateUSDValue(amount, priceData) {
    if (!priceData || !priceData.price) {
      return '0';
    }
    
    const amountBN = BigInt(amount);
    const decimals = priceData.decimals || 18;
    const price = parseFloat(priceData.price);
    
    // Convert amount to decimal representation
    const amountDecimal = Number(amountBN) / Math.pow(10, decimals);
    
    // Calculate USD value
    const usdValue = amountDecimal * price;
    
    return usdValue.toString();
  }

  /**
   * Get chain name for display purposes
   * @param {string} chainId - Chain ID
   * @returns {string} Chain name
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
   * Format USD value for display
   * @param {string} usdValue - USD value as string
   * @returns {string} Formatted USD value
   */
  formatUSD(usdValue) {
    const value = parseFloat(usdValue);
    if (value === 0) return '$0.00';
    if (value < 0.01) return `$${value.toFixed(6)}`;
    if (value < 1) return `$${value.toFixed(4)}`;
    if (value < 1000) return `$${value.toFixed(2)}`;
    if (value < 1000000) return `$${(value / 1000).toFixed(2)}K`;
    if (value < 1000000000) return `$${(value / 1000000).toFixed(2)}M`;
    return `$${(value / 1000000000).toFixed(2)}B`;
  }

  /**
   * Save cache to file for persistence
   * @param {string} filename - Cache file path
   */
  saveCache(filename = 'price-cache.json') {
    const cacheData = Object.fromEntries(this.cache);
    fs.writeFileSync(filename, JSON.stringify(cacheData, null, 2));
    console.log(`Price cache saved to: ${filename}`);
  }

  /**
   * Load cache from file
   * @param {string} filename - Cache file path
   */
  loadCache(filename = 'price-cache.json') {
    try {
      if (fs.existsSync(filename)) {
        const cacheData = JSON.parse(fs.readFileSync(filename, 'utf8'));
        this.cache = new Map(Object.entries(cacheData));
        console.log(`Price cache loaded from: ${filename} (${this.cache.size} entries)`);
      }
    } catch (error) {
      console.log(`Could not load price cache: ${error.message}`);
    }
  }

  /**
   * Clear the in-memory cache
   */
  clearCache() {
    this.cache.clear();
    console.log('Price cache cleared');
  }

  /**
   * Get cache statistics
   * @returns {Object} Cache statistics
   */
  getCacheStats() {
    return {
      size: this.cache.size,
      keys: Array.from(this.cache.keys())
    };
  }
}

// Export the class
module.exports = PriceFetcher;

// If run directly, provide a simple test
if (require.main === module) {
  async function test() {
    const fetcher = new PriceFetcher();
    
    try {
      // Test with a known token (WETH on Ethereum) - use a recent timestamp
      const recentTimestamp = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
      console.log(`Testing with timestamp: ${recentTimestamp} (${new Date(recentTimestamp * 1000).toISOString()})`);
      
      const price = await fetcher.getHistoricalPrice(
        '1', 
        '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', 
        recentTimestamp
      );
      
      console.log('Test result:', price);
      
    } catch (error) {
      console.error('Test failed:', error.message);
    }
  }
  
  test();
}
