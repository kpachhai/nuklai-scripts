#!/bin/bash

# Arguments
PRIVATE_KEY=${1:-"Mjsdj07tXw2p2pMHGwNPLc6dLSJpLBcvPLJSpk3fr9AbBX3jICl8Ka0MH1ieohaGnPGTjYjJ+9cNZ0gyPb8vpw=="}
NUKLAI_RPC_URL=${2:-"http://api-devnet.nuklaivm-dev.net:9650/ext/bc/W3kZDK2seL6J1zqbVtyBgP1xz4QzzZSueXWyHU87Yyd4QhMXx"}
RECIPIENT=${3:-"nuklai1qq69cgkqp3hf8e3qmx7qxrls909xlelg8mf8fnr8rwjjqptwela45uzqm50"}
AMOUNT=${4:-"0.000001"}

LOGFILE="/mnt/c/Users/kiran/Downloads/auto_transfer_NAI.log"
LOCKFILE="/tmp/transfer_and_log.lock"
BLOCKHEIGHT_URL="$NUKLAI_RPC_URL/nuklaiapi"
BLOCKHEIGHT_DATA='{"jsonrpc":"2.0", "id" :1, "method" :"nuklaivm.emissionInfo"}'
TIMEOUT_DURATION="60s"

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

# Log the transaction details
echo "$TIMESTAMP - Block Height: $CURRENT_BLOCK_HEIGHT - Transferred $AMOUNT to $RECIPIENT using RPC URL $NUKLAI_RPC_URL" >> "$LOGFILE"
echo "$TIMESTAMP - Command Output: $COMMAND_OUTPUT" >> "$LOGFILE"

# Remove the lock file
rm -f "$LOCKFILE"
echo "$(date "+%Y-%m-%d %H:%M:%S") - Lock file removed." >> "$LOGFILE"
