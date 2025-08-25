#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Try to load dotenv if available
let dotenv;
try {
  dotenv = require('dotenv');
} catch (e) {
  // dotenv not available, will use process.env directly
}

// Manual .env file loader as fallback
function loadEnvFile() {
  try {
    const envPath = path.join(process.cwd(), '.env');
    if (fs.existsSync(envPath)) {
      const envContent = fs.readFileSync(envPath, 'utf8');
      const lines = envContent.split('\n');
      
      lines.forEach(line => {
        line = line.trim();
        if (line && !line.startsWith('#') && line.includes('=')) {
          const [key, ...valueParts] = line.split('=');
          let value = valueParts.join('=').trim();
          // Remove surrounding quotes if present
          if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
            value = value.slice(1, -1);
          }
          if (key && value) {
            process.env[key] = value;
          }
        }
      });
      
      logInfo('Loaded .env file manually');
      return true;
    }
  } catch (error) {
    logWarning(`Failed to load .env file manually: ${error.message}`);
  }
  return false;
}

// Configuration - will be set by command line arguments
let CONFIG = {
  // Rate limiting: max requests per second
  maxRequestsPerSecond: 1, // Conservative: 1 request per second
  // Delay between requests in milliseconds
  requestDelay: 1500, // 1.5 seconds between requests
  // Retry configuration
  maxRetries: 3,
  baseRetryDelay: 3000, // 3 seconds base delay
};

// Function to load configuration from command line and environment
function loadConfig(args) {
  // Load .env file if dotenv is available
  if (dotenv) {
    dotenv.config();
    logInfo('Loaded .env file using dotenv package');
  } else {
    logWarning('dotenv package not available - trying manual .env loading');
    loadEnvFile();
  }
  
  // Parse command line arguments
  let chainId, apiKey;
  
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--chain-id' && i + 1 < args.length) {
      chainId = args[i + 1];
      i++; // Skip next argument since we consumed it
    } else if (args[i] === '--api-key' && i + 1 < args.length) {
      apiKey = args[i + 1];
      i++; // Skip next argument since we consumed it
    }
  }
  
  if (chainId) {
    // Try to get URL and API key from environment variables
    const urlVar = `VERIFIER_URL_${chainId}`;
    const apiKeyVar = `VERIFIER_API_KEY_${chainId}`;
    
    const baseUrl = process.env[urlVar];
    const envApiKey = process.env[apiKeyVar];
    
    // Debug: show what we're looking for
    logInfo(`Looking for environment variables: ${urlVar} and ${apiKeyVar}`);
    logInfo(`Available environment variables: ${Object.keys(process.env).filter(key => key.startsWith('VERIFIER_')).join(', ')}`);
    
    if (!baseUrl) {
      throw new Error(`No VERIFIER_URL_${chainId} found in environment variables. Available VERIFIER_* variables: ${Object.keys(process.env).filter(key => key.startsWith('VERIFIER_')).join(', ')}`);
    }
    
    CONFIG.baseUrl = baseUrl;
    CONFIG.apiKey = apiKey || envApiKey || '';
    
    logInfo(`Using chain ID: ${chainId}`);
    logInfo(`Base URL: ${baseUrl}`);
    logInfo(`API Key: ${CONFIG.apiKey ? '✓ Set' : '✗ Not set'}`);
    
  } else {
    // Fallback to default values or environment variables
    CONFIG.baseUrl = process.env.VERIFIER_URL || 'https://api.etherscan.io/api';
    CONFIG.apiKey = apiKey || process.env.VERIFIER_API_KEY || '';
    
    logInfo(`Using default configuration`);
    logInfo(`Base URL: ${CONFIG.baseUrl}`);
    logInfo(`API Key: ${CONFIG.apiKey ? '✓ Set' : '✗ Not set'}`);
  }
  
  // Adjust rate limiting based on the explorer
  if (CONFIG.baseUrl.includes('lineascan')) {
    CONFIG.maxRequestsPerSecond = 1;
    CONFIG.requestDelay = 1500;
    logInfo(`Lineascan detected: Using conservative rate limiting (1 req/sec)`);
  } else if (CONFIG.baseUrl.includes('etherscan')) {
    CONFIG.maxRequestsPerSecond = 5;
    CONFIG.requestDelay = 1000 / 5;
    logInfo(`Etherscan detected: Using standard rate limiting (5 req/sec)`);
  } else {
    CONFIG.maxRequestsPerSecond = 2;
    CONFIG.requestDelay = 1000 / 2;
    logInfo(`Generic explorer: Using moderate rate limiting (2 req/sec)`);
  }
}

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logError(message) {
  console.error(`${colors.red}ERROR: ${message}${colors.reset}`);
}

function logSuccess(message) {
  console.log(`${colors.green}✓ ${message}${colors.reset}`);
}

function logWarning(message) {
  console.log(`${colors.yellow}⚠ ${message}${colors.reset}`);
}

function logInfo(message) {
  console.log(`${colors.blue}ℹ ${message}${colors.reset}`);
}

// Sleep function for rate limiting
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Check if a contract is verified with retry logic
async function checkContractVerification(address, retryCount = 0) {
  try {
    // First try to get the ABI - this will only work for verified contracts
    const abiUrl = `${CONFIG.baseUrl}?module=contract&action=getabi&address=${address}&apikey=${CONFIG.apiKey}`;
    
    const abiResponse = await fetch(abiUrl);
    const abiData = await abiResponse.json();
    
    // Check for rate limit errors (Lineascan specific message)
    if (abiData.message && (abiData.message.includes('rate limit') || abiData.message.includes('Max calls per sec'))) {
      if (retryCount < CONFIG.maxRetries) {
        const delay = CONFIG.baseRetryDelay * Math.pow(2, retryCount); // Exponential backoff
        logWarning(`Rate limit hit for ${address}, retrying in ${delay/1000}s... (attempt ${retryCount + 1}/${CONFIG.maxRetries})`);
        await sleep(delay);
        return checkContractVerification(address, retryCount + 1);
      } else {
        return {
          address,
          verified: false,
          reason: `Rate limit exceeded after ${CONFIG.maxRetries} retries`
        };
      }
    }
    
    if (abiData.status === '1' && abiData.result !== 'Contract source code not verified') {
      // Contract is verified - get additional details
      const sourceUrl = `${CONFIG.baseUrl}?module=contract&action=getsourcecode&address=${address}&apikey=${CONFIG.apiKey}`;
      const sourceResponse = await fetch(sourceUrl);
      const sourceData = await sourceResponse.json();
      
      // Check for rate limit errors in source code request (Lineascan specific message)
      if (sourceData.message && (sourceData.message.includes('rate limit') || sourceData.message.includes('Max calls per sec'))) {
        if (retryCount < CONFIG.maxRetries) {
          const delay = CONFIG.baseRetryDelay * Math.pow(2, retryCount); // Exponential backoff
          logWarning(`Rate limit hit for source code of ${address}, retrying in ${delay/1000}s... (attempt ${retryCount + 1}/${CONFIG.maxRetries})`);
          await sleep(delay);
          return checkContractVerification(address, retryCount + 1);
        } else {
          return {
            address,
            verified: true,
            name: 'Verified (details unavailable due to rate limit)',
            compiler: 'Unknown',
            optimization: 'Unknown',
            runs: 'Unknown'
          };
        }
      }
      
      if (sourceData.status === '1') {
        const result = sourceData.result[0];
        return {
          address,
          verified: true,
          name: result.ContractName || 'Unknown',
          compiler: result.CompilerVersion || 'Unknown',
          optimization: result.OptimizationUsed === '1' ? 'Yes' : 'No',
          runs: result.Runs || 'N/A'
        };
      } else {
        return {
          address,
          verified: true,
          name: 'Verified (details unavailable)',
          compiler: 'Unknown',
          optimization: 'Unknown',
          runs: 'Unknown'
        };
      }
    } else {
      // Contract is not verified
      return {
        address,
        verified: false,
        reason: abiData.result || 'Contract not verified'
      };
    }
  } catch (error) {
    if (retryCount < CONFIG.maxRetries) {
      const delay = CONFIG.baseRetryDelay * Math.pow(2, retryCount); // Exponential backoff
      logWarning(`Request failed for ${address}, retrying in ${delay/1000}s... (attempt ${retryCount + 1}/${CONFIG.maxRetries})`);
      await sleep(delay);
      return checkContractVerification(address, retryCount + 1);
    } else {
      return {
        address,
        verified: false,
        reason: `Request failed after ${CONFIG.maxRetries} retries: ${error.message}`
      };
    }
  }
}

// Main function to process all addresses
async function checkAllContracts(jsonFilePath) {
  try {
    // Check if file exists
    if (!fs.existsSync(jsonFilePath)) {
      logError(`File not found: ${jsonFilePath}`);
      process.exit(1);
    }

    // Read and parse JSON file
    const fileContent = fs.readFileSync(jsonFilePath, 'utf8');
    const contracts = JSON.parse(fileContent);

    log(`\n${colors.bright}Contract Verification Status Checker${colors.reset}`);
    log(`===============================================`);
    log(`Input file: ${jsonFilePath}`);
    log(`Total contracts to check: ${Object.keys(contracts).length}`);
    log(`Rate limit: ${CONFIG.maxRequestsPerSecond} requests/second`);
    log(`Retry attempts: ${CONFIG.maxRetries}`);
    log(``);

    if (!CONFIG.apiKey) {
      logWarning('No API key provided. Some explorers may have rate limits.');
      logInfo('Set VERIFIER_API_KEY_<chain_id> environment variable for better access.');
    }

    const results = [];
    const addresses = Object.values(contracts);
    const names = Object.keys(contracts);

    // Process addresses with rate limiting
    for (let i = 0; i < addresses.length; i++) {
      const address = addresses[i];
      const name = names[i];
      
      logInfo(`Checking ${name} (${address})... [${i + 1}/${addresses.length}]`);
      
      const result = await checkContractVerification(address);
      result.contractName = name;
      results.push(result);
      
      // Rate limiting delay
      if (i < addresses.length - 1) {
        logInfo(`Waiting ${CONFIG.requestDelay/1000}s before next request...`);
        await sleep(CONFIG.requestDelay);
      }
    }

    // Display results
    log(`\n${colors.bright}Results:${colors.reset}`);
    log(`========`);
    
    let verifiedCount = 0;
    let unverifiedCount = 0;

    results.forEach(result => {
      if (result.verified) {
        verifiedCount++;
        logSuccess(`${result.contractName}: ${result.address}`);
        log(`   Name: ${result.name}`);
        log(`   Compiler: ${result.compiler}`);
        log(`   Optimization: ${result.optimization}`);
        log(`   Runs: ${result.runs}`);
      } else {
        unverifiedCount++;
        logError(`${result.contractName}: ${result.address}`);
        log(`   Reason: ${result.reason}`);
      }
      log(``);
    });

    // Summary
    log(`\n${colors.bright}Summary:${colors.reset}`);
    log(`========`);
    log(`Total contracts: ${results.length}`);
    log(`Verified: ${colors.green}${verifiedCount}${colors.reset}`);
    log(`Unverified: ${colors.red}${unverifiedCount}${colors.reset}`);

    // Results are only displayed in console, no files saved

  } catch (error) {
    logError(`Failed to process contracts: ${error.message}`);
    process.exit(1);
  }
}

// CLI argument handling
function showUsage() {
  log(`\n${colors.bright}Usage:${colors.reset}`);
  log(`node checkContractVerification.js [options] <json-file-path>`);
  log(`\n${colors.bright}Options:${colors.reset}`);
  log(`--chain-id <id>     Chain ID to use (e.g., 1 for Ethereum, 130 for Unichain)`);
  log(`--api-key <key>     Override API key from environment variables`);
  log(`--help, -h          Show this help message`);
  log(`\n${colors.bright}Environment Variables:${colors.reset}`);
  log(`VERIFIER_URL_<id>   Explorer URL for specific chain ID (e.g., VERIFIER_URL_1, VERIFIER_URL_130)`);
  log(`VERIFIER_API_KEY_<id> API key for specific chain ID (e.g., VERIFIER_API_KEY_1, VERIFIER_API_KEY_130)`);
  log(`VERIFIER_URL        Default explorer URL (fallback)`);
  log(`VERIFIER_API_KEY    Default API key (fallback)`);
  log(`\n${colors.bright}Examples:${colors.reset}`);
  log(`# Check contracts on Ethereum mainnet (chain ID 1)`);
  log(`node checkContractVerification.js --chain-id 1 contracts.json`);
  log(`\n# Check contracts on Unichain (chain ID 130)`);
  log(`node checkContractVerification.js --chain-id 130 contracts.json`);
  log(`\n# Override API key for a specific chain`);
  log(`node checkContractVerification.js --chain-id 1 --api-key your_key contracts.json`);
  log(`\n# Use default configuration`);
  log(`node checkContractVerification.js contracts.json`);
  log(`\n${colors.bright}Example JSON format:${colors.reset}`);
  log(`{
  "balanceTracker": "0x0D52d06ceB8Dcdeeb40Cfd9f17489B350dD7F8a3",
  "eVaultFactory": "0x29a56a1b8214D9Cf7c5561811750D5cBDb45CC8e"
}`);
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    showUsage();
    process.exit(0);
  }

  // Load configuration from command line and environment
  try {
    loadConfig(args);
  } catch (error) {
    logError(`Configuration error: ${error.message}`);
    showUsage();
    process.exit(1);
  }

  // Find the JSON file path (first non-flag argument)
  const jsonFilePath = args.find(arg => !arg.startsWith('--'));
  
  if (!jsonFilePath || !jsonFilePath.endsWith('.json')) {
    logError('Please provide a JSON file path');
    showUsage();
    process.exit(1);
  }

  await checkAllContracts(jsonFilePath);
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logError(`Unhandled Rejection at: ${promise}, reason: ${reason}`);
  process.exit(1);
});

// Run the script
if (require.main === module) {
  main().catch(error => {
    logError(`Script failed: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { checkContractVerification, checkAllContracts }; 