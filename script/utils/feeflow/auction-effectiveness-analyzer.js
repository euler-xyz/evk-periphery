const fs = require('fs');
const path = require('path');

/**
 * Auction Effectiveness Analyzer
 * 
 * Analyzes the effectiveness of fee flow auctions by comparing:
 * - USD value of EUL paid
 * - USD value of assets bought
 * 
 * Output JSON Structure:
 * {
 *   "summary": {
 *     "totalAuctions": number,
 *     "totalEULPaid": number,
 *     "totalEULPaidUSD": number,
 *     "totalAssetsBoughtUSD": number,
 *     "overallDiscount": number, // assetsBoughtUSD - eulPaidUSD
 *     "overallDiscountPercentage": number, // (assetsBoughtUSD - eulPaidUSD) / assetsBoughtUSD * 100
 *     "chainBreakdown": {
 *       "1": { "auctions": number, "discount": number, "discountPercentage": number, "totalEULPaid": number, "totalAssetsBought": number },
 *       "137": { ... },
 *       // ... other chains
 *     }
 *   },
 *   "auctions": [
 *     {
 *       "chainId": string,
 *       "timestamp": number,
 *       "blockNumber": number,
 *       "auctionId": string,
 *       "eulPaid": {
 *         "amount": string, // raw amount
 *         "decimals": number,
 *         "usdValue": number,
 *         "eulPriceUSD": number
 *       },
 *       "assetsBought": [
 *         {
 *           "address": string,
 *           "symbol": string,
 *           "decimals": number,
 *           "amount": string, // raw amount
 *           "usdValue": number,
 *           "assetPriceUSD": number,
 *           "chainId": string
 *         }
 *       ],
 *       "totalAssetsBoughtUSD": number,
 *       "discount": number, // assetsBoughtUSD - eulPaidUSD
 *       "discountPercentage": number, // (assetsBoughtUSD - eulPaidUSD) / assetsBoughtUSD * 100
 *     }
 *   ],
 *   "assetBreakdown": {
 *     "0x...": { // asset address
 *       "symbol": string,
 *       "totalAmountBought": string,
 *       "totalUSDValue": number,
 *       "appearances": number,
 *       "averagePrice": number,
 *       "chains": string[]
 *     }
 *   },
 *   "timestampBreakdown": {
 *     "2024-01": { // month
 *       "auctions": number,
 *       "totalEULPaid": number,
 *       "totalAssetsBought": number,
 *       "discount": number,
 *       "discountPercentage": number
 *     }
 *   },
 *   "analysis": {
 *     "generatedAt": string,
 *     "feeflowAnalysisFile": string,
 *     "priceDataFile": string,
 *     "totalProcessingTime": number,
 *     "errors": [
 *       {
 *         "auctionId": string,
 *         "error": string,
 *         "timestamp": number
 *       }
 *     ]
 *   }
 * }
 */

class AuctionEffectivenessAnalyzer {
  constructor() {
    this.feeflowAnalysisFile = path.join(__dirname, 'feeflow-analysis.json');
    this.priceDataFile = path.join(__dirname, 'feeflow-asset-prices.json');
    this.outputFile = path.join(__dirname, 'auction-effectiveness-analysis.json');
    
    this.feeflowData = null;
    this.priceData = null;
    this.analysis = {
      summary: {},
      auctions: [],
      assetBreakdown: {},
      timestampBreakdown: {},
      analysis: {
        errors: []
      }
    };
  }

  async run() {
    console.log('🚀 Starting Auction Effectiveness Analysis...');
    
    try {
      // Load data
      await this.loadData();
      
      // Analyze each auction
      await this.analyzeAuctions();
      
      // Generate summary statistics
      this.generateSummary();
      
      // Generate asset breakdown
      this.generateAssetBreakdown();
      
      // Generate timestamp breakdown
      this.generateTimestampBreakdown();
      
      // Finalize analysis metadata
      this.finalizeAnalysis();
      
      // Save results
      await this.saveResults();
      
      console.log('✅ Analysis complete!');
      this.printSummary();
      
    } catch (error) {
      console.error('❌ Analysis failed:', error);
      throw error;
    }
  }

  async loadData() {
    console.log('📊 Loading data files...');
    
    // Load feeflow analysis
    if (!fs.existsSync(this.feeflowAnalysisFile)) {
      throw new Error(`Feeflow analysis file not found: ${this.feeflowAnalysisFile}`);
    }
    this.feeflowData = JSON.parse(fs.readFileSync(this.feeflowAnalysisFile, 'utf8'));
    
    // Load price data
    if (!fs.existsSync(this.priceDataFile)) {
      throw new Error(`Price data file not found: ${this.priceDataFile}`);
    }
    this.priceData = JSON.parse(fs.readFileSync(this.priceDataFile, 'utf8'));
    
    console.log(`   Loaded ${Object.keys(this.feeflowData.chains || {}).length} chains`);
    console.log(`   Loaded ${Object.keys(this.priceData.assets || {}).length} assets with price data`);
  }

  async analyzeAuctions() {
    console.log('🔍 Analyzing auctions...');
    
    const startTime = Date.now();
    let processedCount = 0;
    let errorCount = 0;
    
    // Process each chain
    for (const [chainId, chainData] of Object.entries(this.feeflowData.chains || {})) {
      console.log(`   Processing chain ${chainId} (${chainData.chainName || 'Unknown'})...`);
      
      for (const auction of chainData.auctions || []) {
        try {
          const auctionAnalysis = await this.analyzeSingleAuction(chainId, auction);
          if (auctionAnalysis) {
            this.analysis.auctions.push(auctionAnalysis);
            processedCount++;
          }
        } catch (error) {
          errorCount++;
          this.analysis.analysis.errors.push({
            auctionId: auction.auctionId || `chain-${chainId}-${auction.timestamp}`,
            error: error.message,
            timestamp: auction.timestamp
          });
          console.log(`     ⚠️  Error processing auction: ${error.message}`);
        }
      }
    }
    
    const processingTime = Date.now() - startTime;
    console.log(`   Processed ${processedCount} auctions in ${processingTime}ms`);
    if (errorCount > 0) {
      console.log(`   ⚠️  ${errorCount} auctions had errors`);
    }
  }

  async analyzeSingleAuction(chainId, auction) {
    const timestamp = auction.timestamp;
    const eulAssetKey = '1:0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b';
    
    // Get EUL price at auction time
    const eulPriceData = this.getAssetPriceAtTimestamp(eulAssetKey, timestamp);
    if (!eulPriceData) {
      console.log(`     ⚠️  No EUL price data for timestamp ${timestamp}, trying to find closest...`);
      // Try to find any EUL price data
      const eulAsset = this.priceData.assets[eulAssetKey];
      if (eulAsset && eulAsset.prices) {
        console.log(`     Available EUL timestamps: ${Object.keys(eulAsset.prices).slice(0, 5).join(', ')}...`);
      }
      throw new Error(`No EUL price data available for timestamp ${timestamp}`);
    }
    
    // Calculate EUL paid in USD
    let eulPaidAmount = auction.eulPaid;
    if (eulPaidAmount === null || eulPaidAmount === undefined || isNaN(eulPaidAmount)) {
      console.log(`     ⚠️  Invalid eulPaid value: ${eulPaidAmount}, defaulting to '0'`);
      eulPaidAmount = '0';
    }
    
    // EUL amounts are in wei (smallest unit), need to convert to whole tokens
    const eulPaid = {
      amount: eulPaidAmount.toString(),
      decimals: 18,
      usdValue: this.calculateUSDValue(eulPaidAmount.toString(), 18, eulPriceData.price),
      eulPriceUSD: eulPriceData.price
    };
    
    // Process assets bought
    const assetsBought = [];
    let totalAssetsBoughtUSD = 0;
    
    for (const asset of auction.assets || []) {
      const assetKey = `${chainId}:${asset.underlyingAsset}`;
      const assetPriceData = this.getAssetPriceAtTimestamp(assetKey, timestamp);
      
      if (assetPriceData) {
        const assetUSDValue = this.calculateUSDValue(
          asset.underlyingAmount || '0',
          assetPriceData.decimals,
          assetPriceData.price
        );
        
        assetsBought.push({
          address: asset.underlyingAsset,
          symbol: assetPriceData.symbol,
          decimals: assetPriceData.decimals,
          amount: asset.underlyingAmount || '0',
          usdValue: assetUSDValue,
          assetPriceUSD: assetPriceData.price,
          chainId: chainId
        });
        
        totalAssetsBoughtUSD += assetUSDValue;
      } else {
        console.log(`     ⚠️  No price data for asset ${assetKey} at timestamp ${timestamp}`);
      }
    }
    
    // Calculate discount metrics
    const discount = totalAssetsBoughtUSD - eulPaid.usdValue;
    const discountPercentage = totalAssetsBoughtUSD > 0 ? (discount / totalAssetsBoughtUSD) * 100 : 0;
    
    return {
      chainId,
      timestamp,
      blockNumber: auction.blockNumber,
      auctionId: auction.auctionId || `chain-${chainId}-${timestamp}`,
      txHash: auction.txHash || null,
      eulPaid,
      assetsBought,
      totalAssetsBoughtUSD,
      discount,
      discountPercentage
    };
  }

  getAssetPriceAtTimestamp(assetKey, timestamp) {
    const asset = this.priceData.assets[assetKey];
    if (!asset || !asset.prices) return null;
    
    // Find the closest timestamp (within 6 hours = 21600 seconds)
    const timeWindow = 21600;
    let closestPrice = null;
    let minDiff = Infinity;
    
    for (const [priceTimestamp, priceData] of Object.entries(asset.prices)) {
      const diff = Math.abs(parseInt(priceTimestamp) - timestamp);
      if (diff <= timeWindow && diff < minDiff) {
        minDiff = diff;
        closestPrice = {
          price: priceData.price || priceData,
          decimals: asset.decimals,
          symbol: asset.symbol
        };
      }
    }
    
    return closestPrice;
  }

  calculateUSDValue(amount, decimals, priceUSD) {
    if (amount === null || amount === undefined || isNaN(amount)) {
      return 0;
    }
    
    if (priceUSD === null || priceUSD === undefined || isNaN(priceUSD)) {
      return 0;
    }
    
    try {
      const amountBN = BigInt(amount);
      const divisor = BigInt(10 ** decimals);
      const amountFloat = Number(amountBN) / Number(divisor);
      return amountFloat * priceUSD;
    } catch (error) {
      return 0;
    }
  }

  generateSummary() {
    console.log('📈 Generating summary statistics...');
    
    const auctions = this.analysis.auctions;
    const totalAuctions = auctions.length;
    
    let totalEULPaid = 0n;
    let totalEULPaidUSD = 0;
    let totalAssetsBoughtUSD = 0;
    
    const chainBreakdown = {};
    
    for (const auction of auctions) {
      // Aggregate totals
      totalEULPaid += BigInt(auction.eulPaid.amount);
      totalEULPaidUSD += auction.eulPaid.usdValue;
      totalAssetsBoughtUSD += auction.totalAssetsBoughtUSD;
      
      // Chain breakdown
      if (!chainBreakdown[auction.chainId]) {
        chainBreakdown[auction.chainId] = {
          auctions: 0,
          totalEULPaid: 0,
          totalAssetsBought: 0
        };
      }
      
      chainBreakdown[auction.chainId].auctions++;
      chainBreakdown[auction.chainId].totalEULPaid += auction.eulPaid.usdValue;
      chainBreakdown[auction.chainId].totalAssetsBought += auction.totalAssetsBoughtUSD;
    }
    
    // Calculate chain discounts
    for (const chainData of Object.values(chainBreakdown)) {
      chainData.discount = chainData.totalAssetsBought - chainData.totalEULPaid;
      chainData.discountPercentage = chainData.totalAssetsBought > 0 ? 
        (chainData.discount / chainData.totalAssetsBought) * 100 : 0;
    }
    
    this.analysis.summary = {
      totalAuctions,
      totalEULPaid: totalEULPaid.toString(),
      totalEULPaidUSD,
      totalAssetsBoughtUSD,
      overallDiscount: totalAssetsBoughtUSD - totalEULPaidUSD,
      overallDiscountPercentage: totalAssetsBoughtUSD > 0 ? ((totalAssetsBoughtUSD - totalEULPaidUSD) / totalAssetsBoughtUSD) * 100 : 0,

      chainBreakdown
    };
  }

  generateAssetBreakdown() {
    console.log('🏦 Generating asset breakdown...');
    
    const assetMap = {};
    
    for (const auction of this.analysis.auctions) {
      for (const asset of auction.assetsBought) {
        const key = asset.address.toLowerCase();
        
        if (!assetMap[key]) {
          assetMap[key] = {
            symbol: asset.symbol,
            totalAmountBought: 0n,
            totalUSDValue: 0,
            appearances: 0,
            averagePrice: 0,
            chains: new Set(),
            totalPriceUSD: 0
          };
        }
        
        assetMap[key].totalAmountBought += BigInt(asset.amount);
        assetMap[key].totalUSDValue += asset.usdValue;
        assetMap[key].appearances++;
        assetMap[key].chains.add(asset.chainId);
        assetMap[key].totalPriceUSD += asset.assetPriceUSD;
      }
    }
    
    // Convert BigInts to strings and calculate averages
    for (const asset of Object.values(assetMap)) {
      asset.totalAmountBought = asset.totalAmountBought.toString();
      asset.averagePrice = asset.totalPriceUSD / asset.appearances;
      asset.chains = Array.from(asset.chains);
      delete asset.totalPriceUSD;
    }
    
    this.analysis.assetBreakdown = assetMap;
  }

  generateTimestampBreakdown() {
    console.log('📅 Generating timestamp breakdown...');
    
    const monthMap = {};
    
    for (const auction of this.analysis.auctions) {
      const date = new Date(auction.timestamp * 1000);
      const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
      
      if (!monthMap[monthKey]) {
        monthMap[monthKey] = {
          auctions: 0,
          totalEULPaid: 0,
          totalAssetsBought: 0
        };
      }
      
      monthMap[monthKey].auctions++;
      monthMap[monthKey].totalEULPaid += auction.eulPaid.usdValue;
      monthMap[monthKey].totalAssetsBought += auction.totalAssetsBoughtUSD;
    }
    
    // Calculate monthly discounts
    for (const monthData of Object.values(monthMap)) {
      monthData.discount = monthData.totalAssetsBought - monthData.totalEULPaid;
      monthData.discountPercentage = monthData.totalAssetsBought > 0 ? 
        (monthData.discount / monthData.totalAssetsBought) * 100 : 0;
    }
    
    this.analysis.timestampBreakdown = monthMap;
  }

  finalizeAnalysis() {
    this.analysis.analysis = {
      generatedAt: new Date().toISOString(),
      feeflowAnalysisFile: path.basename(this.feeflowAnalysisFile),
      priceDataFile: path.basename(this.priceDataFile),
      totalProcessingTime: Date.now(),
      errors: this.analysis.analysis.errors || []
    };
  }

  async saveResults() {
    console.log('💾 Saving analysis results...');
    
    const outputPath = this.outputFile;
    fs.writeFileSync(outputPath, JSON.stringify(this.analysis, null, 2));
    
    console.log(`   Results saved to: ${outputPath}`);
  }

  printSummary() {
    const summary = this.analysis.summary;
    
    console.log('\n📊 ANALYSIS SUMMARY');
    console.log('==================');
    console.log(`Total Auctions: ${summary.totalAuctions}`);
    console.log(`Total EUL Paid: ${summary.totalEULPaid} ($${summary.totalEULPaidUSD.toFixed(2)})`);
    console.log(`Total Assets Bought: $${summary.totalAssetsBoughtUSD.toFixed(2)}`);
    console.log(`Overall Discount: $${summary.overallDiscount.toFixed(2)} (${summary.overallDiscountPercentage.toFixed(2)}%)`);
    
    console.log('\n🔗 Chain Breakdown:');
    for (const [chainId, data] of Object.entries(summary.chainBreakdown)) {
      console.log(`  Chain ${chainId}: ${data.auctions} auctions, $${data.discount.toFixed(2)} discount (${data.discountPercentage.toFixed(2)}%)`);
    }
    
    if (this.analysis.analysis.errors.length > 0) {
      console.log(`\n⚠️  ${this.analysis.analysis.errors.length} auctions had errors during processing`);
    }
  }
}

// Run the analyzer if called directly
if (require.main === module) {
  const analyzer = new AuctionEffectivenessAnalyzer();
  analyzer.run().catch(console.error);
}

module.exports = AuctionEffectivenessAnalyzer;
