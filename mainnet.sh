source mainnet.env

echo "Initial balance of $PUBLIC_KEY"
cast balance $PUBLIC_KEY -r $LOCAL_RPC_URL

# send 1ether to $PUBLIC_KEY

# local, -0.02ether
# yarn run deploy

# local, -0.02ether
# yarn run senduop:local

# Polycli loadtest
totalUop=2000
batchSize=1
concurrency=50
rateLimit=50

totalTx=$((totalUop / $batchSize))
requestsPerThread=$((totalTx / $concurrency))

echo "totalUop: $totalUop"
echo "batchSize: $batchSize"
echo "totalTx: $totalTx"
echo "concurrency: $concurrency"
echo "requestsPerThread: $requestsPerThread"

# Start loadtest
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
    -v 700 \
    --account-factory $ACCOUNT_FACTORY \
    --config $CONFIG \
    --entry-point $ENTRYPOINT \
    --helper $HELPER \
    --payable-account $PAYABLE_ACCOUNT \
    --token-receiver $TOKEN_RECEIVER \
    --validator $WEBAUTHN_VALIDATOR \
    2>&1 | tee tmp_${batchSize}.log

# Prettify log by removing ANSI escape codes
sed 's/\x1b\[[0-9;]*m//g' tmp_${batchSize}.log > mainnet_${batchSize}.log
rm tmp_${batchSize}.log

echo "Final balance of $PUBLIC_KEY"
cast balance $PUBLIC_KEY -r $LOCAL_RPC_URL