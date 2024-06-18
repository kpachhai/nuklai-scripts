#!/bin/bash

# Arguments
LOCKFILE=${1:-"/tmp/auto_transfer_$(uuidgen).lock"}
PRIVATE_KEY=${2:-"Mjsdj07tXw2p2pMHGwNPLc6dLSJpLBcvPLJSpk3fr9AbBX3jICl8Ka0MH1ieohaGnPGTjYjJ+9cNZ0gyPb8vpw=="}
RECIPIENT=${3:-"nuklai1qpg4ecapjymddcde8sfq06dshzpxltqnl47tvfz0hnkesjz7t0p35d5fnr3"}
AMOUNT=${4:-"0.00000001"}

LOGFILE="/mnt/c/Users/kiran/Downloads/auto_transfer_NAI.log"
TIMEOUT_DURATION="30s"
CHAIN_ID="2qUd9HkKRx44ZRi8fbhCBJ3yHG8fVHNuj7ESyPYnf18dNDuEpu"

# List of RPC endpoints
RPC_URLS=(
    127.0.0.1
)

log_message() {
    local message=$1
    flock -n /tmp/auto_transfer_log.lock -c "echo \"$(date "+%Y-%m-%d %H:%M:%S") - $message\" >> \"$LOGFILE\""
}

log_message "Script started for $LOCKFILE."

# Check if the lock file exists
if [ -e "$LOCKFILE" ]; then
    log_message "Script for $LOCKFILE is already running."
    exit 1
fi

# Create the lock file
touch "$LOCKFILE"
log_message "Lock file $LOCKFILE created."

for RPC_URL in "${RPC_URLS[@]}"; do
    NUKLAI_RPC_URL="http://$RPC_URL:9650/ext/bc/$CHAIN_ID"

    # Retrieve block height
    BLOCKHEIGHT_RESPONSE=$(curl -s -X POST --data '{"jsonrpc":"2.0", "id" :1, "method" :"nuklaivm.emissionInfo"}' -H 'content-type:application/json;' "$NUKLAI_RPC_URL/nuklaiapi")
    CURRENT_BLOCK_HEIGHT=$(echo $BLOCKHEIGHT_RESPONSE | jq -r '.result.currentBlockHeight')

    # Execute the command with a timeout
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    COMMAND_OUTPUT=$(timeout $TIMEOUT_DURATION /home/kpachhai/repos/github.com/kpachhai/nuklai-scripts/go/transfer_nai/transfer_nai "$PRIVATE_KEY" "$NUKLAI_RPC_URL" "$RECIPIENT" "$AMOUNT" 2>&1)

    # Check if the command timed out
    if [ $? -eq 124 ]; then
        COMMAND_OUTPUT="Command timed out after $TIMEOUT_DURATION"
    fi

    # Log the transaction details
    log_message "Block Height with $RPC_URL: $CURRENT_BLOCK_HEIGHT - $COMMAND_OUTPUT To Recipient: $RECIPIENT"

    # Sleep for 30 seconds before the next execution
    sleep 30s
done

# Remove the lock file
rm -f "$LOCKFILE"
log_message "Lock file removed."
