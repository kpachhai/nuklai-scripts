#!/bin/bash

LOGFILE="/mnt/c/Users/kiran/Downloads/auto_transfer_NAI.log"
LOCKFILE="/tmp/transfer_and_log.lock"
BLOCKHEIGHT_URL="http://api-devnet.nuklaivm-dev.net:9650/ext/bc/W3kZDK2seL6J1zqbVtyBgP1xz4QzzZSueXWyHU87Yyd4QhMXx/nuklaiapi"
BLOCKHEIGHT_DATA='{"jsonrpc":"2.0", "id" :1, "method" :"nuklaivm.emissionInfo"}'
TIMEOUT_DURATION="60s"
PRIVATE_KEY="oMTRzLZs9ktLtn51f1qta9QVVDcibyiWFQA8xmccXs0Ju36ThIC09IQCKlXaKAnKh/FLe6I2Ja4q3rfw07TrVA=="
NUKLAI_RPC_URL="http://api-devnet.nuklaivm-dev.net:9650/ext/bc/W3kZDK2seL6J1zqbVtyBgP1xz4QzzZSueXWyHU87Yyd4QhMXx"
RECIPIENT="nuklai1qq69cgkqp3hf8e3qmx7qxrls909xlelg8mf8fnr8rwjjqptwela45uzqm50"
AMOUNT="0.000001"

echo "$(date "+%Y-%m-%d %H:%M:%S") - Script started." >> "$LOGFILE"

# Check if the lock file exists
if [ -e "$LOCKFILE" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Script is already running." >> "$LOGFILE"
    exit 1
fi

# Create the lock file
touch "$LOCKFILE"
echo "$(date "+%Y-%m-%d %H:%M:%S") - Lock file created." >> "$LOGFILE"

# Retrieve block height
BLOCKHEIGHT_RESPONSE=$(curl -s -X POST --data "$BLOCKHEIGHT_DATA" -H 'content-type:application/json;' "$BLOCKHEIGHT_URL")
CURRENT_BLOCK_HEIGHT=$(echo $BLOCKHEIGHT_RESPONSE | jq -r '.result.currentBlockHeight')

# Execute the command with a timeout
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
COMMAND_OUTPUT=$(timeout $TIMEOUT_DURATION /home/kpachhai/repos/github.com/kpachhai/nuklai-scripts/go/transfer_nai/transfer_nai "$PRIVATE_KEY" "$NUKLAI_RPC_URL" "$RECIPIENT" "$AMOUNT" 2>&1)

# Check if the command timed out
if [ $? -eq 124 ]; then
    COMMAND_OUTPUT="Command timed out after $TIMEOUT_DURATION"
fi

echo "$TIMESTAMP - Block Height: $CURRENT_BLOCK_HEIGHT - $COMMAND_OUTPUT" >> "$LOGFILE"

# Remove the lock file
rm -f "$LOCKFILE"
echo "$(date "+%Y-%m-%d %H:%M:%S") - Lock file removed." >> "$LOGFILE"
