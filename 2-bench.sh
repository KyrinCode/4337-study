#!/bin/bash

# Add Go binaries to PATH
export PATH=$PATH:~/go/bin

source .env
# Polycli loadtest
totalUop=$TOTAL_UOP
batchSize=$BATCH_SIZE
concurrency=$CONCURRENCY
rateLimit=$RATE_LIMIT
callDataType=$CALLDATA_TYPE

totalTx=$((totalUop / $batchSize))
requestsPerThread=$((totalTx / $concurrency))

echo -e "\n============== Test Parameters =================="
echo -e "Total UOP: $totalUop"
echo -e "Batch Size: $batchSize"
echo -e "Total Transactions: $totalTx"
echo -e "Concurrency: $concurrency"
echo -e "Rate Limit: $rateLimit"
echo -e "Call Data Type: $callDataType"

# Generate timestamp for file suffix
TIMESTAMP=$(date +"%Y%m%d_%H%M")
RESULT_FILE="result_${TIMESTAMP}.out"
PROF_FILE="prof_${TIMESTAMP}.bin"

echo -e "\n============== Capture Performance Profile ==============="
echo "To capture performance profile, run the following command in another terminal:"
echo -e "curl http://localhost:6060/debug/pprof/profile?seconds=120 > ${PROF_FILE}"

echo -e "\n============== Monitor Stress Logs ==============="
echo "To monitor stress logs, run the following command in another terminal:"
echo -e "cd cdk-erigon/test && docker-compose logs --tail 10 -f | grep TotalDuration-batch"
echo -e "docker logs xlayer-seq --tail 10 -f 2>&1 | grep TotalDuration-batch"

echo "Starting loadtest ... (Results will be saved to $RESULT_FILE)"

# Start loadtest
(
polycli loadtest erc4337 \
    --requests $requestsPerThread \
    --concurrency $concurrency \
    --rate-limit $rateLimit \
    --uop-batch-size $batchSize \
    --gas-price 1 \
    --gas-limit 10000000 \
    --rpc-url $LOCAL_RPC_URL \
    --legacy \
    --private-key $PRIVATE_KEY \
    -v 500 \
    --account-factory $ACCOUNT_FACTORY \
    --pay $PAY \
    --test-erc20 $TEST_ERC20 \
    --config $CONFIG \
    --entry-point $ENTRYPOINT \
    --helper $HELPER \
    --payable-account $PAYABLE_ACCOUNT \
    --token-receiver $TOKEN_RECEIVER \
    --validator $WEBAUTHN_VALIDATOR \
    --calldata-file $CALLDATA_FILE
) >> $RESULT_FILE 2>&1

# Prettify log by removing ANSI escape codes
sed -i.bak 's/\x1b\[[0-9;]*m//g' $RESULT_FILE

# Filter and extract TPS value
echo "Extracting TPS data..." >> $RESULT_FILE
TPS_VALUE=$(grep "tps=" $RESULT_FILE | sed 's/.*tps=\x1B\[0m\([0-9.]*\).*/\1/' | tail -n 1)
echo "TPS: $TPS_VALUE" >> $RESULT_FILE

# Display results in terminal
echo -e "Final TPS: $TPS_VALUE"
echo "Detailed results saved in $RESULT_FILE"
