#!/usr/bin/env bash
# Copyright (C) 2024, AllianceBlock. All rights reserved.
# See the file LICENSE for licensing terms.

rm -rf .nuklai-cli

TMPDIR=/tmp/nuklaivm-deploy
CLUSTER=nuklai-1717707297

# Import cli
$TMPDIR/nuklai-cli chain import-cli $HOME/.avalanche-cli/nodes/inventories/$CLUSTER/clusterInfo.yaml

# Import main devnet account key
$TMPDIR/nuklai-cli key import ed25519 /mnt/c/Users/kiran/Downloads/devnetwallet.pk

# Import keys
# Loop through each CLOUD_ID in the VALIDATOR list
for CLOUD_ID in $(yq e '.VALIDATOR[].CLOUD_ID' $HOME/.avalanche-cli/nodes/inventories/$CLUSTER/clusterInfo.yaml); do
    # Construct the command
    CMD="$TMPDIR/nuklai-cli key import bls $HOME/.avalanche-cli/nodes/$CLOUD_ID/signer.key"

    # Execute the command
    echo "Executing: $CMD"
    $CMD
done

# Set to the default key
$TMPDIR/nuklai-cli key set

# Transfer some NAI to the validators
for i in {1..2}; do
    echo "Executing transfer action $i"
    $TMPDIR/nuklai-cli action transfer
done

# Register the validators
for i in {1..1}; do
    echo "Registering the validator $i"
    $TMPDIR/nuklai-cli key set
    $TMPDIR/nuklai-cli action register-validator-stake manual
done

# Delegate user stake
$TMPDIR/nuklai-cli key set
for i in {1..1}; do
    echo "Delegating to the validator $i"
    $TMPDIR/nuklai-cli action delegate-user-stake manual
    sleep 5
done

# Check the staked validators
$TMPDIR/nuklai-cli emission staked-validators

# Check the emission info
$TMPDIR/nuklai-cli emission info
