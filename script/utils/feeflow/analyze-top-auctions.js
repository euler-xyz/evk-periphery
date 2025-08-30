const fs = require('fs');
const path = require('path');

/**
 * Top Auctions Analyzer
 * 
 * Analyzes auctions to find:
 * 1. Biggest losses for DAO (high discount = DAO got little EUL for lots of assets)
 * 2. Biggest gains for DAO (negative discount = DAO got more EUL than assets were worth)
 */

class TopAuctionsAnalyzer {
  constructor() {
    this.analysisFile = path.join(__dirname, 'auction-effectiveness-analysis.json');
    this.feeflowFile = path.join(__dirname, 'feeflow-analysis.json');
    this.analysis = null;
    this.feeflowData = null;
  }

  async run() {
    console.log('🔍 Analyzing Top Auctions by Discount...\n');
    
    try {
      // Load data
      await this.loadData();
      
      // Find top auctions by discount (biggest losses for DAO)
      this.findTopLosses();
      
      // Find top auctions by negative discount (biggest gains for DAO)
      this.findTopGains();
      
      // Show summary statistics
      this.showSummary();
      
    } catch (error) {
      console.error('❌ Analysis failed:', error);
      throw error;
    }
  }

  async loadData() {
    // Load auction effectiveness analysis
    if (!fs.existsSync(this.analysisFile)) {
      throw new Error(`Analysis file not found: ${this.analysisFile}`);
    }
    this.analysis = JSON.parse(fs.readFileSync(this.analysisFile, 'utf8'));
    
    // Load feeflow analysis for transaction hashes
    if (!fs.existsSync(this.feeflowFile)) {
      throw new Error(`Feeflow analysis file not found: ${this.feeflowFile}`);
    }
    this.feeflowData = JSON.parse(fs.readFileSync(this.feeflowFile, 'utf8'));
    
    console.log(`📊 Loaded ${this.analysis.auctions.length} auctions for analysis`);
  }

  findTopLosses() {
    console.log('💰 TOP 20 AUCTIONS - BIGGEST LOSSES FOR DAO');
    console.log('   (High discount = DAO got little EUL for lots of assets)');
    console.log('=' .repeat(120));
    
    // Sort auctions by discount (highest first)
    const sortedAuctions = [...this.analysis.auctions]
      .filter(auction => auction.discount > 0) // Only positive discounts (losses)
      .sort((a, b) => b.discount - a.discount)
      .slice(0, 20);
    
    console.log('Rank | Discount    | EUL Paid    | Assets Bought | Chain | Date                | TX Hash');
    console.log('-----|-------------|-------------|---------------|-------|---------------------|----------');
    
    sortedAuctions.forEach((auction, index) => {
      const rank = index + 1;
      const date = new Date(auction.timestamp * 1000).toISOString().split('T')[0];
      const txHash = auction.txHash || 'N/A';
      
      console.log(
        `${rank.toString().padStart(4)} | ` +
        `$${auction.discount.toFixed(2).padStart(10)} | ` +
        `$${auction.eulPaid.usdValue.toFixed(2).padStart(10)} | ` +
        `$${auction.totalAssetsBoughtUSD.toFixed(2).padStart(12)} | ` +
        `${auction.chainId.padStart(5)} | ` +
        `${date} | ` +
        `${txHash}`
      );
    });
    
    console.log('\n');
  }

  findTopGains() {
    console.log('💸 TOP 20 AUCTIONS - BIGGEST GAINS FOR DAO');
    console.log('   (Negative discount = DAO got more EUL than assets were worth)');
    console.log('=' .repeat(120));
    
    // Sort auctions by discount (lowest first - most negative)
    const sortedAuctions = [...this.analysis.auctions]
      .filter(auction => auction.discount < 0) // Only negative discounts (gains)
      .sort((a, b) => a.discount - b.discount)
      .slice(0, 20);
    
    console.log('Rank | Gain        | EUL Paid    | Assets Bought | Chain | Date                | TX Hash');
    console.log('-----|-------------|-------------|---------------|-------|---------------------|----------');
    
    sortedAuctions.forEach((auction, index) => {
      const rank = index + 1;
      const date = new Date(auction.timestamp * 1000).toISOString().split('T')[0];
      const txHash = auction.txHash || 'N/A';
      const gain = Math.abs(auction.discount); // Convert negative to positive for display
      
      console.log(
        `${rank.toString().padStart(4)} | ` +
        `$${gain.toFixed(2).padStart(10)} | ` +
        `$${auction.eulPaid.usdValue.toFixed(2).padStart(10)} | ` +
        `$${auction.totalAssetsBoughtUSD.toFixed(2).padStart(12)} | ` +
        `${auction.chainId.padStart(5)} | ` +
        `${date} | ` +
        `${txHash}`
      );
    });
    
    console.log('\n');
  }

  showSummary() {
    const auctions = this.analysis.auctions;
    const totalAuctions = auctions.length;
    
    // Calculate statistics
    const positiveDiscounts = auctions.filter(a => a.discount > 0);
    const negativeDiscounts = auctions.filter(a => a.discount < 0);
    const zeroDiscounts = auctions.filter(a => a.discount === 0);
    
    const totalLosses = positiveDiscounts.reduce((sum, a) => sum + a.discount, 0);
    const totalGains = negativeDiscounts.reduce((sum, a) => sum + Math.abs(a.discount), 0);
    
    console.log('📊 SUMMARY STATISTICS');
    console.log('=' .repeat(50));
    console.log(`Total Auctions: ${totalAuctions}`);
    console.log(`Losses for DAO: ${positiveDiscounts.length} auctions ($${totalLosses.toFixed(2)})`);
    console.log(`Gains for DAO: ${negativeDiscounts.length} auctions ($${totalGains.toFixed(2)})`);
    console.log(`Neutral: ${zeroDiscounts.length} auctions`);
    console.log(`Net Result: $${(totalGains - totalLosses).toFixed(2)}`);
    
    // Show top chains by losses
    const chainLosses = {};
    positiveDiscounts.forEach(auction => {
      if (!chainLosses[auction.chainId]) chainLosses[auction.chainId] = 0;
      chainLosses[auction.chainId] += auction.discount;
    });
    
    const topLossChains = Object.entries(chainLosses)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 5);
    
    console.log('\n🏆 TOP 5 CHAINS BY TOTAL LOSSES:');
    topLossChains.forEach(([chainId, totalLoss], index) => {
      console.log(`  ${index + 1}. Chain ${chainId}: $${totalLoss.toFixed(2)}`);
    });
    
    // Show top chains by gains
    const chainGains = {};
    negativeDiscounts.forEach(auction => {
      if (!chainGains[auction.chainId]) chainGains[auction.chainId] = 0;
      chainGains[auction.chainId] += Math.abs(auction.discount);
    });
    
    const topGainChains = Object.entries(chainGains)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 5);
    
    console.log('\n🏆 TOP 5 CHAINS BY TOTAL GAINS:');
    topGainChains.forEach(([chainId, totalGain], index) => {
      console.log(`  ${index + 1}. Chain ${chainId}: $${totalGain.toFixed(2)}`);
    });
  }
}

// Run the analyzer if called directly
if (require.main === module) {
  const analyzer = new TopAuctionsAnalyzer();
  analyzer.run().catch(console.error);
}

module.exports = TopAuctionsAnalyzer;
