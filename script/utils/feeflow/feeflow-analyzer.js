#!/usr/bin/env node

const { createPublicClient, http, decodeEventLog, parseEther, formatEther } = require('viem');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Load FeeFlowController ABI from external file
const FEEFLOW_ABI = JSON.parse(fs.readFileSync(path.join(__dirname, '../../../../euler-interfaces/abis/FeeFlowController.json'), 'utf8'));

// Load EVault ABI from external file (contains ERC20 Transfer event and ERC4626 functions)
const EVault_ABI = JSON.parse(fs.readFileSync(path.join(__dirname, '../../../../euler-interfaces/abis/EVault.json'), 'utf8'));

/**
 * Dynamically discover available chains from environment variables
 */
function discoverChains() {
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
 * Load production chains from EulerChains.json
 */
function loadProductionChains() {
  try {
    const chainsPath = path.join(__dirname, '../../../../euler-interfaces/EulerChains.json');
    const chainsData = JSON.parse(fs.readFileSync(chainsPath, 'utf8'));
    
    // Filter for production chains only
    const productionChains = chainsData.filter(chain => chain.status === 'production');
    
    // Extract chain IDs
    return productionChains.map(chain => chain.chainId.toString());
  } catch (error) {
    console.error('Failed to load production chains from EulerChains.json:', error.message);
    return [];
  }
}

/**
 * Initialize the global analysis result structure
 */
function initializeAnalysisResult() {
  return {
    global: {
      totalChains: 0,
      totalAuctions: 0,
      totalEulPaid: '0'
    },
    chains: {}
  };
}

/**
 * Load addresses from the euler-interfaces directory
 */
function loadAddresses(chainId) {
  const addressesPath = path.join(__dirname, '../../../../euler-interfaces', 'addresses', chainId.toString());
  
  try {
    const peripheryAddresses = JSON.parse(fs.readFileSync(path.join(addressesPath, 'PeripheryAddresses.json'), 'utf8'));
    const tokenAddresses = JSON.parse(fs.readFileSync(path.join(addressesPath, 'TokenAddresses.json'), 'utf8'));
    const multisigAddresses = JSON.parse(fs.readFileSync(path.join(addressesPath, 'MultisigAddresses.json'), 'utf8'));
    
    return {
      feeFlowController: peripheryAddresses.feeFlowController,
      eulToken: tokenAddresses.EUL,
      daoMultisig: multisigAddresses.DAO
    };
  } catch (error) {
    console.error(`Failed to load addresses for chain ${chainId}:`, error.message);
    return null;
  }
}

/**
 * Create a viem client for a specific chain
 */
function createClient(chainId, chains) {
  const chain = chains[chainId];
  if (!chain || !chain.rpc) {
    throw new Error(`No RPC URL configured for chain ${chainId}`);
  }
  
  return createPublicClient({
    chain: { id: chainId },
    transport: http(chain.rpc)
  });
}

/**
 * Get the deployment block of the FeeFlow contract
 */
async function getDeploymentBlock(client, feeFlowAddress) {
  try {
    // Get the latest block
    const latestBlock = await client.getBlockNumber();
    
    // Start searching from genesis block
    const searchStart = 0;
    
    console.log(`  Searching for deployment block from genesis...`);
    
    // Binary search for the exact deployment block
    let left = searchStart;
    let right = Number(latestBlock);
    let deploymentBlock = right;
    
    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      
      try {
        const code = await client.getBytecode({ 
          address: feeFlowAddress, 
          blockNumber: BigInt(mid) 
        });
        
        if (code && code !== '0x') {
          // Contract exists at this block, deployment block is at or before this
          deploymentBlock = mid;
          right = mid - 1;
        } else {
          // Contract doesn't exist at this block, deployment block is after this
          left = mid + 1;
        }
      } catch (error) {
        // If we can't query this block, move right
        left = mid + 1;
      }
    }
    
    console.log(`  Found deployment block: ${deploymentBlock}`);
    return deploymentBlock;
    
  } catch (error) {
    console.error('Failed to get deployment block:', error.message);
    // Fallback: start from a reasonable recent block
    return Math.max(0, Number(await client.getBlockNumber()) - 1000000); // 1M blocks ago
  }
}

/**
 * Parse transaction logs to extract asset transfers
 */
async function parseTransactionLogs(client, txHash, blockNumber, addresses, buyEvent) {
  try {
    // Get all logs for this transaction
    const logs = await client.getLogs({
      fromBlock: blockNumber,
      toBlock: blockNumber,
      transactionHash: txHash
    });
    
    const assetTransfers = [];
    
    // We already have the EUL transfer info from the Buy event
    // buyer = who sends EUL, paymentAmount = EUL amount
    const eulTransfer = {
      from: buyEvent.args.buyer,
      to: addresses.daoMultisig, // EUL goes to DAO
      value: buyEvent.args.paymentAmount.toString()
    };
    
    // Look for asset transfers to the assetsReceiver
    for (const log of logs) {
      try {
        if (log.address !== addresses.feeFlowController) {
                  // Check if this is an asset transfer (vault shares)
        const decoded = decodeEventLog({
          abi: EVault_ABI,
          data: log.data,
          topics: log.topics
        });
          
          if (decoded.eventName === 'Transfer') {
            const { from, to, value } = decoded.args;
            
            // Look for transfers FROM FeeFlow TO the assetsReceiver
            if (from === addresses.feeFlowController && to === buyEvent.args.assetsReceiver) {
              // This is a vault share transfer to the assetsReceiver
              assetTransfers.push({
                vault: log.address, // The vault address
                to: to,
                shares: value.toString()
              });
            }
          }
        }
      } catch (decodeError) {
        // Skip logs we can't decode
        continue;
      }
    }
    
    return { eulTransfer, assetTransfers };
  } catch (error) {
    console.error(`Failed to parse transaction ${txHash}:`, error.message);
    return { eulTransfer: null, assetTransfers: [] };
  }
}

/**
 * Convert vault shares to underlying assets using ERC4626
 */
async function convertSharesToAssets(client, vaultAddress, shares, blockNumber) {
  try {
    const [assets, underlyingAsset] = await Promise.all([
      client.readContract({
        address: vaultAddress,
        abi: EVault_ABI,
        functionName: 'convertToAssets',
        args: [shares],
        blockNumber
      }),
      client.readContract({
        address: vaultAddress,
        abi: EVault_ABI,
        functionName: 'asset',
        blockNumber
      })
    ]);
    
    return {
      assets: assets.toString(),
      underlyingAsset
    };
  } catch (error) {
    console.error(`Failed to convert shares for vault ${vaultAddress}:`, error.message);
    return { assets: '0', underlyingAsset: null };
  }
}

/**
 * Analyze a single auction transaction
 */
async function analyzeAuction(client, txHash, blockNumber, addresses, chainId, buyEvent) {
  const { eulTransfer, assetTransfers } = await parseTransactionLogs(client, txHash, blockNumber, addresses, buyEvent);
  
  if (!eulTransfer) {
    return null;
  }
  
  // Get the actual block timestamp
  const block = await client.getBlock({ blockNumber: BigInt(blockNumber) });
  
  const auction = {
    txHash,
    blockNumber: Number(blockNumber),
    timestamp: Number(block.timestamp),
    eulPaid: eulTransfer.value,
    assets: []
  };
  
  // Process each asset transfer
  for (const transfer of assetTransfers) {
    const { assets, underlyingAsset } = await convertSharesToAssets(
      client, 
      transfer.vault, 
      transfer.shares, 
      blockNumber
    );
    
    auction.assets.push({
      vault: transfer.vault,
      underlyingAsset,
      shares: transfer.shares,
      underlyingAmount: assets
    });
  }
  
  return auction;
}

/**
 * Save global analysis results to JSON file
 */
function saveGlobalResults(results, filename = null) {
  if (!filename) {
    // Use default filename in the feeflow directory
    filename = path.join(__dirname, 'feeflow-analysis.json');
  }
  
  // Convert BigInt values to strings for JSON serialization
  const serializableResults = JSON.parse(JSON.stringify(results, (key, value) => {
    if (typeof value === 'bigint') {
      return value.toString();
    }
    return value;
  }));
  
  fs.writeFileSync(filename, JSON.stringify(serializableResults, null, 2));
  console.log(`Results saved to: ${filename}`);
  return filename;
}



/**
 * Load existing analysis results from JSON file
 */
function loadExistingResults(filename) {
  try {
    if (fs.existsSync(filename)) {
      const data = fs.readFileSync(filename, 'utf8');
      const results = JSON.parse(data);
      
      console.log(`Loaded existing results from: ${filename}`);
      console.log(`  Chains already processed: ${Object.keys(results.chains).join(', ')}`);
      
      return results;
    }
  } catch (error) {
    console.log(`Could not load existing results: ${error.message}`);
  }
  return null;
}

/**
 * Determine search range for resuming analysis
 * If resuming, start from the last processed block + 1
 * If fresh start, start from deployment block
 */
async function determineSearchRange(client, chainId, addresses, existingResults) {
  if (!existingResults || !existingResults.chains[chainId]) {
    // Fresh start - search from deployment
    const deploymentBlock = await getDeploymentBlock(client, addresses.feeFlowController);
    const latestBlock = await client.getBlockNumber();
    return {
      fromBlock: Number(deploymentBlock),
      toBlock: Number(latestBlock),
      isResume: false
    };
  }
  
  // Resume - find the highest block number from existing auctions
  const existingChain = existingResults.chains[chainId];
  let lastAuctionBlock = 0;
  
  for (const auction of existingChain.auctions) {
    if (auction.blockNumber > lastAuctionBlock) {
      lastAuctionBlock = auction.blockNumber;
    }
  }
  
  if (lastAuctionBlock === 0) {
    // No auctions found, start from deployment
    const deploymentBlock = await getDeploymentBlock(client, addresses.feeFlowController);
    const latestBlock = await client.getBlockNumber();
    return {
      fromBlock: Number(deploymentBlock),
      toBlock: Number(latestBlock),
      isResume: false
    };
  }
  
  // Resume from the next block after the last auction
  const latestBlock = await client.getBlockNumber();
  const resumeBlock = lastAuctionBlock + 1;
  
  console.log(`  Resuming from block ${resumeBlock} (last auction: ${lastAuctionBlock})`);
  console.log(`  Searching blocks ${resumeBlock} to ${latestBlock} for new auctions...`);
  
  return {
    fromBlock: resumeBlock,
    toBlock: Number(latestBlock),
    isResume: true
  };
}

/**
 * Main analysis function for a single chain
 */
async function analyzeChain(chainId, chains, existingResults = null) {
  console.log(`\n=== Analyzing Chain ${chainId} ===`);
  
  const addresses = loadAddresses(chainId);
  if (!addresses) {
    console.log(`Skipping chain ${chainId} - failed to load addresses`);
    return null;
  }
  
  const client = createClient(chainId, chains);
  
  try {
    // Check if the contract exists
    const contractCode = await client.getBytecode({ address: addresses.feeFlowController });
    if (!contractCode || contractCode === '0x') {
      console.log(`Chain ${chainId}: FeeFlow contract not found`);
      return null;
    }
    
    // Determine search range (fresh start or resume)
    const { fromBlock, toBlock, isResume } = await determineSearchRange(client, chainId, addresses, existingResults);
    
    // Dynamic chunk sizing: start with 10k, fallback to 2k if needed
    let chunkSize = 10000;
    let chunkSizeDetermined = false;
    
    console.log(`Searching blocks ${fromBlock} to ${toBlock} with dynamic chunk sizing...`);
    
    const buyEvents = [];
    
    for (let chunkStart = fromBlock; chunkStart <= toBlock; chunkStart += chunkSize) {
      const chunkEnd = Math.min(chunkStart + chunkSize - 1, toBlock);
      
      console.log(`  Processing blocks ${chunkStart}-${chunkEnd} / ${toBlock}...`);
      
      try {
        // Add timeout to prevent hanging
        const chunkEvents = await Promise.race([
          client.getLogs({
            address: addresses.feeFlowController,
            event: FEEFLOW_ABI.find(item => item.type === 'event' && item.name === 'Buy'),
            fromBlock: BigInt(chunkStart),
            toBlock: BigInt(chunkEnd)
          }),
          new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Timeout after 30 seconds')), 30000)
          )
        ]);
        
        buyEvents.push(...chunkEvents);
        
        if (chunkEvents.length > 0) {
          console.log(`    ✓ Found ${chunkEvents.length} Buy events`);
        } else {
          console.log(`    ✓ No events found`);
        }
        
        // If we successfully used a smaller chunk size, remember it for this chain
        if (!chunkSizeDetermined && chunkSize < 10000) {
          chunkSizeDetermined = true;
          console.log(`    ✓ Using ${chunkSize}-block chunks for this chain`);
        }
        
      } catch (error) {
        console.log(`    ✗ Error: ${error.message}`);
        
        // If it's a 413 error (request too large) and we haven't determined chunk size yet
        if (error.message.includes('413') && !chunkSizeDetermined && chunkSize === 10000) {
          console.log(`    ⚠️  RPC limit exceeded, reducing chunk size to 2000 blocks...`);
          chunkSize = 2000;
          // Retry this chunk with smaller size
          chunkStart -= 10000; // Go back to retry this chunk
          continue;
        }
        
        // If 2000 blocks also fails, reduce to 1000 (minimum)
        if (error.message.includes('413') && !chunkSizeDetermined && chunkSize === 2000) {
          console.log(`    ⚠️  RPC limit still exceeded, reducing chunk size to 1000 blocks...`);
          chunkSize = 1000;
          // Retry this chunk with smaller size
          chunkStart -= 2000; // Go back to retry this chunk
          continue;
        }
        
        if (error.message.includes('Timeout')) {
          console.log(`    Skipping chunk due to timeout`);
        }
        // Continue with next chunk
      }
    }
    
    if (buyEvents.length === 0) {
      console.log(`Chain ${chainId}: No Buy events found`);
      return null;
    }
    
    console.log(`Chain ${chainId}: Found ${buyEvents.length} Buy events, analyzing auctions...`);
    
    // Collect all auction data
    const auctions = [];
    let totalEulPaid = 0n;
    
    for (let i = 0; i < buyEvents.length; i++) {
      const event = buyEvents[i];
      console.log(`  Processing auction ${i + 1}/${buyEvents.length} (block ${event.blockNumber})...`);
      
      // Analyze this auction
      const auction = await analyzeAuction(
        client, 
        event.transactionHash, 
        event.blockNumber, 
        addresses, 
        chainId,
        event
      );
      
      if (auction) {
        auctions.push(auction);
        totalEulPaid += BigInt(auction.eulPaid);
        console.log(`    ✓ Found ${auction.assets.length} assets`);
      } else {
        console.log(`    ✗ Failed to analyze auction`);
      }
    }
    
    // Create chain results structure
    const chainResults = {
      summary: {
        totalAuctions: auctions.length,
        totalEulPaid: totalEulPaid.toString()
      },
      addresses: {
        feeFlowController: addresses.feeFlowController,
        eulToken: addresses.eulToken,
        daoMultisig: addresses.daoMultisig
      },
      auctions: auctions
    };
    
    console.log(`Chain ${chainId}: ${auctions.length} auctions, ${formatEther(totalEulPaid)} EUL`);
    
    return chainResults;
    
  } catch (error) {
    console.error(`Error analyzing chain ${chainId}:`, error.message);
    return null;
  }
}

/**
 * Main function
 */
async function main() {
  let args = process.argv.slice(2);
  
  // Discover available chains dynamically
  const availableChains = discoverChains();
  
  // Check for resume flag
  const resumeIndex = args.indexOf('--resume');
  let existingResults = null;
  let filename = null;
  
  if (resumeIndex !== -1) {
    if (resumeIndex + 1 >= args.length) {
      console.error('--resume requires a filename');
      process.exit(1);
    }
    filename = args[resumeIndex + 1];
    existingResults = loadExistingResults(filename);
    if (!existingResults) {
      console.error(`Could not load results from: ${filename}`);
      process.exit(1);
    }
    // Remove resume args from chain IDs
    args.splice(resumeIndex, 2);
  }
  
  // Check for output flag
  const outputIndex = args.indexOf('--output');
  let outputFile = null;
  
  if (outputIndex !== -1) {
    if (outputIndex + 1 >= args.length) {
      console.error('--output requires a filename');
      process.exit(1);
    }
    outputFile = args[outputIndex + 1];
    console.log(`Output will be saved to: ${outputFile}`);
    
    // Remove output args from chain IDs
    args.splice(outputIndex, 2);
  }
  
  // If no chain IDs provided and we're not resuming, use production chains
  if (args.length === 0 && !existingResults) {
    // No chain IDs provided, use all production chains from EulerChains.json
    const productionChainIds = loadProductionChains();
    
    if (productionChainIds.length === 0) {
      console.log('Usage: node feeflow-analyzer.js <chain_id1> [chain_id2] ... [--resume filename.json] [--output filename.json]');
      console.log('Example: node feeflow-analyzer.js 1 10 137');
      console.log('Example: node feeflow-analyzer.js 56 --resume feeflow-analysis.json');
      console.log('Example: node feeflow-analyzer.js 1 56 --output custom-results.json');
      console.log('Or run without arguments to analyze all production chains');
      console.log('\nAvailable chains:');
      Object.entries(availableChains).forEach(([id, chain]) => {
        console.log(`  ${id}: ${chain.rpc ? 'RPC configured' : 'No RPC'}`);
      });
      process.exit(1);
    }
    
    console.log(`No chain IDs provided. Using all production chains: ${productionChainIds.join(', ')}`);
    args = productionChainIds;
  }
  
  // If resuming and no chain IDs specified, use chains from existing results
  if (args.length === 0 && existingResults) {
    const existingChainIds = Object.keys(existingResults.chains).map(id => parseInt(id));
    console.log(`Resuming with chains from existing results: ${existingChainIds.join(', ')}`);
    args = existingChainIds.map(id => id.toString());
  }
  
  const chainIds = args.map(id => parseInt(id)).filter(id => !isNaN(id) && availableChains[id]);
  
  if (chainIds.length === 0) {
    console.error('No valid chain IDs provided or chains not configured');
    process.exit(1);
  }
  
  // Initialize or load global analysis result
  const globalResults = existingResults || initializeAnalysisResult();
  
  if (existingResults) {
    console.log(`Resuming analysis. Chains already processed: ${Object.keys(existingResults.chains).join(', ')}`);
    
    // For resuming, we want to process ALL requested chains (including existing ones)
    // to find new auctions since the last run
    console.log(`Processing all requested chains to find new auctions since last run`);
  } else {
    console.log(`Starting FeeFlow efficiency analysis for chains: ${chainIds.join(', ')}`);
  }
  
  // Determine the output filename to use
  // If --output is specified, use that; otherwise use the resume file or default
  const finalOutputFile = outputFile || filename || path.join(__dirname, 'feeflow-analysis.json');
  
  // Analyze each chain
  for (const chainId of chainIds) {
    const chainResults = await analyzeChain(chainId, availableChains, existingResults);
    
    if (chainResults) {
      // Merge with existing results if resuming
      if (existingResults && existingResults.chains[chainId]) {
        const existingChain = existingResults.chains[chainId];
        const existingAuctions = existingChain.auctions || [];
        const newAuctions = chainResults.auctions || [];
        
        // Combine existing and new auctions
        const allAuctions = [...existingAuctions, ...newAuctions];
        
        // Recalculate chain totals
        let totalEulPaid = 0n;
        for (const auction of allAuctions) {
          totalEulPaid += BigInt(auction.eulPaid);
        }
        
        // Update chain results
        chainResults.auctions = allAuctions;
        chainResults.summary.totalAuctions = allAuctions.length;
        chainResults.summary.totalEulPaid = totalEulPaid.toString();
        
        console.log(`  Merged ${existingAuctions.length} existing + ${newAuctions.length} new auctions = ${allAuctions.length} total`);
      }
      
      // Add/update chain results in global structure
      globalResults.chains[chainId] = chainResults;
      
      // Save results after each chain (incremental save)
      if (finalOutputFile) {
        saveGlobalResults(globalResults, finalOutputFile);
      } else {
        const savedFilename = saveGlobalResults(globalResults);
        // Update filename for subsequent saves
        if (!filename) filename = savedFilename;
      }
    }
  }
  
  // Recalculate global totals from all chains
  let totalChains = 0;
  let totalAuctions = 0;
  let totalEulPaid = 0n;
  
  for (const chainData of Object.values(globalResults.chains)) {
    totalChains++;
    totalAuctions += chainData.summary.totalAuctions;
    totalEulPaid += BigInt(chainData.summary.totalEulPaid);
  }
  
  globalResults.global.totalChains = totalChains;
  globalResults.global.totalAuctions = totalAuctions;
  globalResults.global.totalEulPaid = totalEulPaid.toString();
  
  // Display global summary
  console.log(`\nGlobal Summary:`);
  console.log(`  ${globalResults.global.totalChains} chains, ${globalResults.global.totalAuctions} auctions`);
  console.log(`  ${formatEther(globalResults.global.totalEulPaid)} EUL total`);
  
  // Save final results
  saveGlobalResults(globalResults, finalOutputFile);
  console.log(`Final results saved to: ${finalOutputFile}`);
  
  // Ensure clean exit
  process.exit(0);
}

// Run the script
if (require.main === module) {
  main().catch(console.error);
}

module.exports = {
  analyzeChain,
  analyzeAuction,
  parseTransactionLogs,
  convertSharesToAssets,
  loadProductionChains
};
