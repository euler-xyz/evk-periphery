#!/bin/bash
# findVaultsByAdapter.sh
#
# Finds all Euler V2 vaults that rely on a specific oracle adapter.
# Enumerates vaults from the EVault factory, checks each vault's oracle router,
# and reports vaults whose (asset, unitOfAccount) pair is configured to use the
# target adapter (either as a direct config or as the router's fallback oracle).
#
# Usage:
#   ./findVaultsByAdapter.sh <adapter_address> [options]
#
# Options:
#   --rpc-url <url>        RPC endpoint (default: $DEPLOYMENT_RPC_URL_1 from .env)
#   --factory <address>    EVault factory (default: 0x29a56a1b8214D9Cf7c5561811750D5cBDb45CC8e)
#   --router-factory <addr> Oracle router factory (default: 0x70B3f6F61b7Bf237DF04589DdAA842121072326A)
#   --parallel <n>         Number of parallel workers (default: 30)
#   --env-file <path>      Path to .env file (default: .env in script directory's parent)
#
# Examples:
#   ./findVaultsByAdapter.sh 0x28E36Ea7481934a651DA81483358C67A51583b85
#   ./findVaultsByAdapter.sh 0x28E3... --rpc-url https://eth.llamarpc.com --parallel 10

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Defaults
ADAPTER=""
RPC_URL=""
EVAULT_FACTORY="0x29a56a1b8214D9Cf7c5561811750D5cBDb45CC8e"
ROUTER_FACTORY="0x70B3f6F61b7Bf237DF04589DdAA842121072326A"
PARALLEL=30
ENV_FILE="$REPO_DIR/.env"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --rpc-url)    RPC_URL="$2"; shift 2 ;;
    --factory)    EVAULT_FACTORY="$2"; shift 2 ;;
    --router-factory) ROUTER_FACTORY="$2"; shift 2 ;;
    --parallel)   PARALLEL="$2"; shift 2 ;;
    --env-file)   ENV_FILE="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [ -z "$ADAPTER" ]; then
        ADAPTER="$1"
      else
        echo "Unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$ADAPTER" ]; then
  echo "Usage: $0 <adapter_address> [options]" >&2
  echo "Run with --help for full usage." >&2
  exit 1
fi

# Source .env for RPC_URL if not provided via flag
if [ -z "$RPC_URL" ]; then
  if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    RPC_URL="${DEPLOYMENT_RPC_URL_1:-}"
  fi
  if [ -z "$RPC_URL" ]; then
    echo "Error: No RPC URL. Provide --rpc-url or set DEPLOYMENT_RPC_URL_1 in $ENV_FILE" >&2
    exit 1
  fi
fi

# Verify cast is available
if ! command -v cast &>/dev/null; then
  echo "Error: 'cast' (foundry) not found in PATH" >&2
  exit 1
fi

ADAPTER_LOWER=$(echo "$ADAPTER" | tr '[:upper:]' '[:lower:]')
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Target adapter: $ADAPTER"
echo "EVault factory: $EVAULT_FACTORY"
echo "Router factory: $ROUTER_FACTORY"
echo "Parallel workers: $PARALLEL"
echo ""

# Step 1: Fetch oracle routers from factory
echo "Fetching oracle routers..."
ROUTER_COUNT=$(cast call "$ROUTER_FACTORY" "getDeploymentsListLength()(uint256)" --rpc-url "$RPC_URL")
echo "  Found $ROUTER_COUNT routers"

ROUTERS_RAW=$(cast call "$ROUTER_FACTORY" "getDeploymentsListSlice(uint256,uint256)(address[])" 0 "$ROUTER_COUNT" --rpc-url "$RPC_URL")
echo "$ROUTERS_RAW" | tr ',' '\n' | tr -d '[]' | tr -d ' ' | grep '0x' | tr '[:upper:]' '[:lower:]' > "$TMPDIR/routers.txt"
echo "  Loaded $(wc -l < "$TMPDIR/routers.txt") router addresses"

# Step 2: Fetch all vaults
echo "Fetching vaults..."
VAULT_COUNT=$(cast call "$EVAULT_FACTORY" "getProxyListLength()(uint256)" --rpc-url "$RPC_URL")
echo "  Found $VAULT_COUNT vaults"

> "$TMPDIR/vaults.txt"
BATCH=200
for ((i=0; i<VAULT_COUNT; i+=BATCH)); do
  END=$((i + BATCH))
  if [ "$END" -gt "$VAULT_COUNT" ]; then END=$VAULT_COUNT; fi
  SLICE=$(cast call "$EVAULT_FACTORY" "getProxyListSlice(uint256,uint256)(address[])" "$i" "$END" --rpc-url "$RPC_URL")
  echo "$SLICE" | tr ',' '\n' | tr -d '[]' | tr -d ' ' | grep '0x' >> "$TMPDIR/vaults.txt"
done
echo "  Loaded $(wc -l < "$TMPDIR/vaults.txt") vault addresses"

# Step 3: Write per-vault check script
cat > "$TMPDIR/check.sh" << 'CHECKEOF'
#!/bin/bash
VAULT=$1
RPC=$2
TARGET=$3
ROUTERS_FILE=$4

ORACLE=$(cast call "$VAULT" "oracle()(address)" --rpc-url "$RPC" 2>/dev/null)
if [ -z "$ORACLE" ] || [ "$ORACLE" = "0x0000000000000000000000000000000000000000" ]; then exit 0; fi

ORACLE_LOWER=$(echo "$ORACLE" | tr '[:upper:]' '[:lower:]')
if ! grep -qi "$ORACLE_LOWER" "$ROUTERS_FILE" 2>/dev/null; then exit 0; fi

ASSET=$(cast call "$VAULT" "asset()(address)" --rpc-url "$RPC" 2>/dev/null)
UOA=$(cast call "$VAULT" "unitOfAccount()(address)" --rpc-url "$RPC" 2>/dev/null)
if [ -z "$ASSET" ] || [ -z "$UOA" ]; then exit 0; fi

CONFIGURED=$(cast call "$ORACLE" "getConfiguredOracle(address,address)(address)" "$ASSET" "$UOA" --rpc-url "$RPC" 2>/dev/null)
if [ -n "$CONFIGURED" ]; then
  CONFIGURED_LOWER=$(echo "$CONFIGURED" | tr '[:upper:]' '[:lower:]')
  if [ "$CONFIGURED_LOWER" = "$TARGET" ]; then
    NAME=$(cast call "$VAULT" "name()(string)" --rpc-url "$RPC" 2>/dev/null | tr -d '"')
    ASSET_SYM=$(cast call "$ASSET" "symbol()(string)" --rpc-url "$RPC" 2>/dev/null | tr -d '"')
    echo "CONFIG_MATCH vault=$VAULT name=\"$NAME\" router=$ORACLE asset=$ASSET ($ASSET_SYM) unitOfAccount=$UOA"
  fi
fi

FALLBACK=$(cast call "$ORACLE" "fallbackOracle()(address)" --rpc-url "$RPC" 2>/dev/null)
if [ -n "$FALLBACK" ]; then
  FALLBACK_LOWER=$(echo "$FALLBACK" | tr '[:upper:]' '[:lower:]')
  if [ "$FALLBACK_LOWER" = "$TARGET" ]; then
    NAME=$(cast call "$VAULT" "name()(string)" --rpc-url "$RPC" 2>/dev/null | tr -d '"')
    echo "FALLBACK_MATCH vault=$VAULT name=\"$NAME\" router=$ORACLE"
  fi
fi
CHECKEOF
chmod +x "$TMPDIR/check.sh"

# Step 4: Scan all vaults in parallel
echo ""
echo "Scanning vaults for adapter usage..."
RESULTS=$(cat "$TMPDIR/vaults.txt" | xargs -P "$PARALLEL" -n 1 -I {} "$TMPDIR/check.sh" {} "$RPC_URL" "$ADAPTER_LOWER" "$TMPDIR/routers.txt" 2>/dev/null)

echo ""
echo "==============================="
echo "         RESULTS"
echo "==============================="
if [ -n "$RESULTS" ]; then
  MATCH_COUNT=$(echo "$RESULTS" | wc -l | tr -d ' ')
  echo "Found $MATCH_COUNT vault(s) using adapter $ADAPTER:"
  echo ""
  echo "$RESULTS"
else
  echo "No vaults found using adapter $ADAPTER"
fi
echo "==============================="
