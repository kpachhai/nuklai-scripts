#!/bin/bash

# Arguments
LOCKFILE=${1:-"/tmp/auto_transfer_$(uuidgen).lock"}
PRIVATE_KEY=${2:-"Mjsdj07tXw2p2pMHGwNPLc6dLSJpLBcvPLJSpk3fr9AbBX3jICl8Ka0MH1ieohaGnPGTjYjJ+9cNZ0gyPb8vpw=="}
RECIPIENT=${3:-"nuklai1qpg4ecapjymddcde8sfq06dshzpxltqnl47tvfz0hnkesjz7t0p35d5fnr3"}
AMOUNT=${4:-"0.00000001"}

LOGFILE="/mnt/c/Users/kiran/Downloads/auto_transfer_NAI.log"
TIMEOUT_DURATION="30s"
CHAIN_ID="JopL8T69GBW1orW4ZkJ1TBRzF97KXaY8e64atDA1v2M12SNqm"
SSH_KEY="/home/kpachhai/.ssh/kpachhai-eu-west-1-avalanche-cli-eu-west-1-kp.pem"
SSH_USER="ubuntu"

# List of RPC endpoints
RPC_URLS=(
"api-devnet.nuklaivm-dev.net"
)

# Array to track block heights
declare -A block_heights

log_message() {
    local message=$1
    flock -n /tmp/auto_transfer_log.lock -c "echo \"$(date "+%Y-%m-%d %H:%M:%S") - $message\" >> \"$LOGFILE\""
}

handle_timeout() {
    local rpc_url=$1
    log_message "Fixing the timeout issue for $rpc_url by restarting the node"
    # ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$SSH_USER@$rpc_url" -i "$SSH_KEY" << 'EOF'
     #   sudo systemctl stop avalanche-cli-docker; sudo rm -rf ~/.avalanchego/chainData ~/.avalanchego/db; sudo systemctl restart avalanche-cli-docker; sudo systemctl restart avalanche-cli-docker; sudo systemctl restart avalanche-cli-docker;
     # TODO: Email kiran.pachhai@nukl.ai
EOF
    log_message "Timeout handling completed for $rpc_url"
}

cleanup() {
    rm -f "$LOCKFILE"
    log_message "Lock file removed."
}

# Ensure lock file is removed on script exit
trap cleanup EXIT

log_message "Script started for $LOCKFILE."

# Check if the lock file exists
if [ -e "$LOCKFILE" ]; then
    log_message "Script for $LOCKFILE is already running."
    exit 1
fi

# Create the lock file
touch "$LOCKFILE"
log_message "Lock file $LOCKFILE created."

# Flag to track if node stalled has been handled
node_stalled_handled=false

for RPC_URL in "${RPC_URLS[@]}"; do
    NUKLAI_RPC_URL="http://$RPC_URL:9650/ext/bc/$CHAIN_ID"
    if [ "$RPC_URL" == "api-devnet.nuklaivm-dev.net" ]; then
        NUKLAI_RPC_URL="https://$RPC_URL:9650/ext/bc/$CHAIN_ID"
    fi
    log_message "Executing transaction with $NUKLAI_RPC_URL"

    # Retrieve block height
    BLOCKHEIGHT_RESPONSE=$(curl -s -X POST --data '{"jsonrpc":"2.0", "id" :1, "method" :"nuklaivm.emissionInfo"}' -H 'content-type:application/json;' "$NUKLAI_RPC_URL/nuklaiapi")
    CURRENT_BLOCK_HEIGHT=$(echo $BLOCKHEIGHT_RESPONSE | jq -r '.result.currentBlockHeight')

    # Store block height for the current RPC URL
    block_heights[$RPC_URL]=$CURRENT_BLOCK_HEIGHT

    # Execute the command with a timeout and log output to $LOGFILE
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    COMMAND_OUTPUT=$(timeout $TIMEOUT_DURATION /home/kpachhai/.nvm/versions/node/v20.9.0/bin/node /home/kpachhai/repos/github.com/kpachhai/nuklai-scripts/js/sdk-demo/transaction.js "$PRIVATE_KEY" "http://$RPC_URL:9650" "$RECIPIENT" "$AMOUNT" 2>&1 | tee -a "$LOGFILE")
    COMMAND_EXIT_CODE=${PIPESTATUS[0]}

    # Log the transaction details
    log_message "Block Height with $RPC_URL: $CURRENT_BLOCK_HEIGHT - $COMMAND_OUTPUT"

    # Check if block height is lower than any previous RPC URL
    if [ "$RPC_URL" != "api-devnet.nuklaivm-dev.net" ]; then
        for prev_url in "${!block_heights[@]}"; do
            if [ "$RPC_URL" != "$prev_url" ] && [ "$CURRENT_BLOCK_HEIGHT" -lt "${block_heights[$prev_url]}" ]; then
                log_message "Block height for $RPC_URL ($CURRENT_BLOCK_HEIGHT) is lower than $prev_url (${block_heights[$prev_url]}). Triggering timeout handling."
                COMMAND_OUTPUT="Command timed out or failed after $TIMEOUT_DURATION"
                log_message "$COMMAND_OUTPUT"

                # Timeout handling only once
                if [ "$node_stalled_handled" = false ]; then
                    handle_timeout "$RPC_URL"
                    node_stalled_handled=true
                else
                    log_message "Node stalled occurred, but handling already done. Skipping $RPC_URL."
                fi
                break  # No need to check other URLs
            fi
        done
    fi

    # Sleep for 5 seconds before the next execution
    sleep 5
done

# Remove the lock file
cleanup
