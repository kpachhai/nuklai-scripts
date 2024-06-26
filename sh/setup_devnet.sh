#!/usr/bin/env bash
# Copyright (C) 2024, AllianceBlock. All rights reserved.
# See the file LICENSE for licensing terms.

rm -rf .nuklai-cli

TMPDIR=/tmp/nuklaivm-deploy
CLUSTER=nuklai-1718726898

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
# Make sure to send to:
# nuklai1qqfvz93mskscgfh4lgp0wwhwtj8umzzqhytew028fgg9wy390maxy02pwkw (auto_transfer.sh main account)
# nuklai1qqnrqnhe399wlzn8qmsk2svmpwtp8je86yjnnr9p0qzusvljv9lakqgzxxc (auto_transfer second account)
# nuklai1qfgc2st57mmtzet7ajq4lh6d6rp3ev277ejxpandlzzy35v5fnhf6ccx39e  (sdk account)
for i in {1..3}; do
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
