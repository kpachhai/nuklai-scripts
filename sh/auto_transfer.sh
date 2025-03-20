#!/bin/bash

# Arguments
LOCKFILE=${1:-"/tmp/auto_transfer_$(uuidgen).lock"}
PRIVATE_KEY=${2:-"Mjsdj07tXw2p2pMHGwNPLc6dLSJpLBcvPLJSpk3fr9AbBX3jICl8Ka0MH1ieohaGnPGTjYjJ+9cNZ0gyPb8vpw=="}
RECIPIENT=${3:-"nuklai1qpg4ecapjymddcde8sfq06dshzpxltqnl47tvfz0hnkesjz7t0p35d5fnr3"}
AMOUNT=${4:-"0.00000001"}

LOGFILE="/mnt/c/Users/kiran/Downloads/auto_transfer_NAI.log"
TIMEOUT_DURATION="30s"
CHAIN_ID="24h7hzFfHG2vCXtT1MKsxP1VkYb9kkKHAvhJim1Xb7Y6W15zY5"
SSH_KEY="/home/kpachhai/.ssh/kpachhai-eu-west-1-avalanche-cli-eu-west-1-kp.pem"
SSH_USER="ubuntu"
HEIGHTS_FILE="/tmp/previous_block_heights.txt"  # File to store block heights

# List of RPC endpoints
RPC_URLS=(
  18.201.12.56
  54.170.75.242
  34.243.86.39
  34.243.178.58
  34.244.119.201
  3.250.59.111
  3.255.75.234
  34.253.178.223
  3.252.36.164
  3.254.3.129
  "api-devnet.nuklaivm-dev.net"
)

# Array to track block heights
declare -A block_heights
declare -A previous_block_heights

log_message() {
    local message=$1
    flock -n /tmp/auto_transfer_log.lock -c "echo \"$(date "+%Y-%m-%d %H:%M:%S") - $message\" >> \"$LOGFILE\""
}

send_email() {
    local rpc_url=$1
    local message=$2
    local subject="Possible devnet stall for $rpc_url"
    local recipient="kiran@pachhai.com"

    log_message "Sending email to $recipient with subject: $subject"
    ../py/venv/bin/python ../py/send_email.py "$recipient" "$subject" "$message"

    # ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$SSH_USER@$rpc_url" -i "$SSH_KEY" << 'EOF'
    #    sudo systemctl stop avalanche-cli-docker; sudo rm -rf ~/.avalanchego/chainData ~/.avalanchego/db; sudo systemctl restart avalanche-cli-docker; sudo systemctl restart avalanche-cli-docker; sudo systemctl restart avalanche-cli-docker;
    # EOF

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

# Load previous block heights from the file
if [ -f "$HEIGHTS_FILE" ]; then
    while IFS="=" read -r key value; do
        previous_block_heights["$key"]="$value"
    done < "$HEIGHTS_FILE"
fi

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
    if [[ -z "${previous_block_heights[$RPC_URL]}" ]]; then
        previous_block_heights[$RPC_URL]=0
    fi

    block_heights[$RPC_URL]=$CURRENT_BLOCK_HEIGHT

    # Execute the command with a timeout and log output to $LOGFILE
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    COMMAND_OUTPUT=$(timeout $TIMEOUT_DURATION /home/kpachhai/.nvm/versions/node/v20.9.0/bin/node /home/kpachhai/repos/github.com/kpachhai/nuklai-scripts/js/sdk-demo/transaction.js "$PRIVATE_KEY" "http://$RPC_URL:9650" "$RECIPIENT" "$AMOUNT" 2>&1 | tee -a "$LOGFILE")
    COMMAND_EXIT_CODE=${PIPESTATUS[0]}

    # Log the transaction details
    log_message "Block Height with $RPC_URL: $CURRENT_BLOCK_HEIGHT - $COMMAND_OUTPUT"

    # Check if block height has stopped growing
    if [ "$CURRENT_BLOCK_HEIGHT" -le "${previous_block_heights[$RPC_URL]}" ]; then
        message="Block height for $RPC_URL ($CURRENT_BLOCK_HEIGHT) has stopped growing or is less than the previous height (${previous_block_heights[$RPC_URL]})."
        log_message "${message}. Triggering timeout handling."
        COMMAND_OUTPUT="Command timed out or failed after $TIMEOUT_DURATION"
        log_message "$COMMAND_OUTPUT"
        send_email "$RPC_URL" "$message"
    fi

    # Sleep for 5 seconds before the next execution
    sleep 5
done

# Save the current block heights to the file for the next run
> "$HEIGHTS_FILE"
for url in "${!block_heights[@]}"; do
    echo "$url=${block_heights[$url]}" >> "$HEIGHTS_FILE"
done

# Remove the lock file
cleanup