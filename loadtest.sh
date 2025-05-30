#!/bin/bash
set -e

# Source environment variables if .env file exists
if [ -f .env ]; then
    source .env
fi

# Check for gas price
if [ -z "$GAS_PRICE" ]; then
    echo "Error: GAS_PRICE not set in .env file"
    echo "For fake mainnet, please add GAS_PRICE=1 to your .env file"
    exit 1
else
    gas_price=$GAS_PRICE
fi

echo "----------------------------------------"
echo "Running loadtest with gas price $gas_price"
echo "----------------------------------------"

# Prompt for key parameters
echo "Enter total User Operations to send (e.g. 5000):"
read TOTAL_UOP

echo "Enter concurrency, number of senders & threads (e.g. 100):"
read CONCURRENCY

echo "Enter UOP batch size, number of UOPs per transaction (1 / 5 / 10):"
read BATCH_SIZE

# Optional parameters with defaults
FUND_AMOUNT=${FUND_AMOUNT:-1}
DEPLOY_CONTRACTS=${DEPLOY_CONTRACTS:-false}
LOG_LEVEL=${LOG_LEVEL:-0}
WALLET_SEED=${WALLET_SEED:-"loadtest-deterministic-seed"}

# Export all variables for the script
export GAS_PRICE
export TOTAL_UOP
export BATCH_SIZE
export CONCURRENCY
export RATE_LIMIT
export FUND_AMOUNT
export DEPLOY_CONTRACTS
export LOG_LEVEL
export WALLET_SEED

# Run the loadtest
npx hardhat run scripts/loadtest.ts --network local 2>&1 | tee loadtest_${BATCH_SIZE}.log