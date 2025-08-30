const fs = require('fs');
const path = require('path');

class CoverageChecker {
  constructor() {
    this.analysis = {};
    this.priceData = {};
    this.assetMappings = {};
  }

  loadData() {
    try {
      this.analysis = JSON.parse(fs.readFileSync('feeflow-analysis.json', 'utf8'));
      this.priceData = JSON.parse(fs.readFileSync('feeflow-asset-prices.json', 'utf8'));
      this.assetMappings = JSON.parse(fs.readFileSync('asset-mappings.json', 'utf8'));
      console.log(`✅ Loaded data successfully`);
    } catch (error) {
      console.error('❌ Error loading data:', error.message);
      process.exit(1);
    }
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

  checkCoverage() {
    console.log('\n=== Price Coverage Analysis ===\n');
    
    let totalAssets = 0;
    let completeCoverage = 0;
    let partialCoverage = 0;
    let noCoverage = 0;
    let totalRequiredTimestamps = 0;
    let totalCoveredTimestamps = 0;
    
    const coverageReport = {
      complete: [],
      partial: [],
      missing: [],
      summary: {}
    };

    // Collect all unique assets from analysis
    const allAssets = new Map();
    
    Object.entries(this.analysis.chains).forEach(([chainId, chain]) => {
      chain.auctions.forEach(auction => {
        auction.assets.forEach(asset => {
          const assetKey = `${chainId}:${asset.underlyingAsset}`;
          if (!allAssets.has(assetKey)) {
            allAssets.set(assetKey, {
              chainId,
              address: asset.underlyingAsset,
              chainName: this.getChainName(chainId),
              timestamps: new Set()
            });
          }
          allAssets.get(assetKey).timestamps.add(auction.timestamp);
        });
      });
    });

    console.log(`Found ${allAssets.size} unique assets across all chains\n`);

    // Check coverage for each asset
    for (const [assetKey, assetInfo] of allAssets) {
      totalAssets++;
      const requiredTimestamps = Array.from(assetInfo.timestamps).sort((a, b) => a - b);
      totalRequiredTimestamps += requiredTimestamps.length;
      
      // Check if asset exists in price data
      const priceAsset = this.priceData.assets[assetKey];
      
      if (!priceAsset) {
        // No price data at all
        noCoverage++;
        coverageReport.missing.push({
          assetKey,
          chainId: assetInfo.chainId,
          chainName: assetInfo.chainName,
          address: assetInfo.address,
          requiredTimestamps: requiredTimestamps.length,
          missingTimestamps: requiredTimestamps.length,
          coverage: 0
        });
        
        console.log(`❌ ${assetKey} (${assetInfo.chainName}) - NO COVERAGE`);
        console.log(`   Required: ${requiredTimestamps.length} timestamps`);
        console.log(`   Missing: ${requiredTimestamps.length} timestamps`);
        continue;
      }

      // Asset exists, check timestamp coverage
      const existingTimestamps = Object.keys(priceAsset.prices || {}).map(Number);
      const missingTimestamps = requiredTimestamps.filter(ts => !existingTimestamps.includes(ts));
      const coverage = ((requiredTimestamps.length - missingTimestamps.length) / requiredTimestamps.length) * 100;
      
      totalCoveredTimestamps += existingTimestamps.length;
      
      if (missingTimestamps.length === 0) {
        // Complete coverage
        completeCoverage++;
        coverageReport.complete.push({
          assetKey,
          chainId: assetInfo.chainId,
          chainName: assetInfo.chainName,
          address: assetInfo.address,
          symbol: priceAsset.symbol,
          requiredTimestamps: requiredTimestamps.length,
          coveredTimestamps: existingTimestamps.length,
          coverage: 100,
          metadata: priceAsset.metadata
        });
        
        console.log(`✅ ${assetKey} (${assetInfo.chainName}) - ${priceAsset.symbol || 'Unknown'} - COMPLETE`);
        console.log(`   Coverage: ${existingTimestamps.length}/${requiredTimestamps.length} (100%)`);
        if (priceAsset.metadata) {
          console.log(`   Source: ${priceAsset.metadata.source}${priceAsset.metadata.defiLlamaId ? ` (${priceAsset.metadata.defiLlamaId})` : ''}`);
        }
      } else {
        // Partial coverage
        partialCoverage++;
        coverageReport.partial.push({
          assetKey,
          chainId: assetInfo.chainId,
          chainName: assetInfo.chainName,
          address: assetInfo.address,
          symbol: priceAsset.symbol,
          requiredTimestamps: requiredTimestamps.length,
          coveredTimestamps: existingTimestamps.length,
          missingTimestamps: missingTimestamps.length,
          coverage: coverage,
          metadata: priceAsset.metadata
        });
        
        console.log(`🔄 ${assetKey} (${assetInfo.chainName}) - ${priceAsset.symbol || 'Unknown'} - PARTIAL`);
        console.log(`   Coverage: ${existingTimestamps.length}/${requiredTimestamps.length} (${coverage.toFixed(1)}%)`);
        console.log(`   Missing: ${missingTimestamps.length} timestamps`);
        if (priceAsset.metadata) {
          console.log(`   Source: ${priceAsset.metadata.source}${priceAsset.metadata.defiLlamaId ? ` (${priceAsset.metadata.defiLlamaId})` : ''}`);
        }
      }
    }

    // Generate summary
    coverageReport.summary = {
      totalAssets,
      completeCoverage,
      partialCoverage,
      noCoverage,
      totalRequiredTimestamps,
      totalCoveredTimestamps,
      overallCoverage: ((totalCoveredTimestamps / totalRequiredTimestamps) * 100).toFixed(1)
    };

    // Display summary
    console.log(`\n${'='.repeat(60)}`);
    console.log('📊 COVERAGE SUMMARY');
    console.log(`${'='.repeat(60)}`);
    console.log(`Total Assets: ${totalAssets}`);
    console.log(`Complete Coverage: ${completeCoverage} (${((completeCoverage / totalAssets) * 100).toFixed(1)}%)`);
    console.log(`Partial Coverage: ${partialCoverage} (${((partialCoverage / totalAssets) * 100).toFixed(1)}%)`);
    console.log(`No Coverage: ${noCoverage} (${((noCoverage / totalAssets) * 100).toFixed(1)}%)`);
    console.log(`\nTotal Required Timestamps: ${totalRequiredTimestamps}`);
    console.log(`Total Covered Timestamps: ${totalCoveredTimestamps}`);
    console.log(`Overall Coverage: ${coverageReport.summary.overallCoverage}%`);

    // Save detailed report
    const reportFile = 'coverage-report.json';
    fs.writeFileSync(reportFile, JSON.stringify(coverageReport, null, 2));
    console.log(`\n📄 Detailed report saved to: ${reportFile}`);

    // Show assets that need attention
    if (coverageReport.missing.length > 0) {
      console.log(`\n🚨 ASSETS WITH NO COVERAGE (${coverageReport.missing.length}):`);
      coverageReport.missing.forEach(asset => {
        console.log(`  ${asset.assetKey} (${asset.chainName}) - ${asset.requiredTimestamps} timestamps needed`);
      });
    }

    if (coverageReport.partial.length > 0) {
      console.log(`\n⚠️  ASSETS WITH PARTIAL COVERAGE (${coverageReport.partial.length}):`);
      coverageReport.partial.forEach(asset => {
        console.log(`  ${asset.assetKey} (${asset.chainName}) - ${asset.symbol} - ${asset.coverage.toFixed(1)}% coverage`);
      });
    }

    return coverageReport;
  }

  run() {
    console.log('🔍 FeeFlow Price Coverage Checker');
    console.log('==================================');
    
    this.loadData();
    this.checkCoverage();
  }
}

// Run the checker
if (require.main === module) {
  const checker = new CoverageChecker();
  checker.run();
}

module.exports = CoverageChecker;
