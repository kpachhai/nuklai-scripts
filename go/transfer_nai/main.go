package main

import (
	"context"
	"encoding/base64"
	"fmt"
	"log"
	"os"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/hypersdk/codec"
	"github.com/ava-labs/hypersdk/crypto/ed25519"
	"github.com/ava-labs/hypersdk/pubsub"
	"github.com/ava-labs/hypersdk/rpc"
	hutils "github.com/ava-labs/hypersdk/utils"
	"github.com/nuklai/nuklaivm/actions"
	"github.com/nuklai/nuklaivm/auth"
	nconsts "github.com/nuklai/nuklaivm/consts"
	nrpc "github.com/nuklai/nuklaivm/rpc"
)

const (
	defaultNuklaiRPCURL = "http://api-devnet.nuklaivm-dev.net:9650/ext/bc/W3kZDK2seL6J1zqbVtyBgP1xz4QzzZSueXWyHU87Yyd4QhMXx"
	defaultRecipient    = "nuklai1qq69cgkqp3hf8e3qmx7qxrls909xlelg8mf8fnr8rwjjqptwela45uzqm50"
	defaultAmount       = "0.0001"
	defaultPrivateKey   = "oMTRzLZs9ktLtn51f1qta9QVVDcibyiWFQA8xmccXs0Ju36ThIC09IQCKlXaKAnKh/FLe6I2Ja4q3rfw07TrVA=="
)

func main() {
	args := os.Args[1:]

	nuklaiRPCURL := defaultNuklaiRPCURL
	recipient := defaultRecipient
	amount := defaultAmount
	privateKeyBase64 := defaultPrivateKey

	if len(args) > 0 {
		privateKeyBase64 = args[0]
	}
	if len(args) > 1 {
		nuklaiRPCURL = args[1]
	}
	if len(args) > 2 {
		recipient = args[2]
	}
	if len(args) > 3 {
		amount = args[3]
	}

	// Decode the private key from base64
	privateKeyBytes, err := base64.StdEncoding.DecodeString(privateKeyBase64)
	if err != nil {
		log.Fatalf("Invalid private key: %v", err)
	}
	privateKey := ed25519.PrivateKey(privateKeyBytes)

	// Initialize the client
	cli := rpc.NewJSONRPCClient(nuklaiRPCURL)
	networkID, _, chainID, err := cli.Network(context.Background())
	if err != nil {
		log.Fatalf("Failed to fetch network info: %v", err)
	}
	ncli := nrpc.NewJSONRPCClient(nuklaiRPCURL, networkID, chainID)
	scli, err := rpc.NewWebSocketClient(nuklaiRPCURL, rpc.DefaultHandshakeTimeout, pubsub.MaxPendingMessages, pubsub.MaxReadMessageSize)
	if err != nil {
		log.Fatalf("Failed to initialize WebSocket client: %v", err)
	}

	// Generate the transfer transaction
	err = transfer(context.Background(), cli, ncli, scli, privateKey, recipient, amount)
	if err != nil {
		log.Fatalf("Transfer failed: %v", err)
	}

	fmt.Println("Transfer successful")
}

func transfer(ctx context.Context, cli *rpc.JSONRPCClient, ncli *nrpc.JSONRPCClient, scli *rpc.WebSocketClient, privateKey ed25519.PrivateKey, recipient string, amount string) error {
	// Validate and parse recipient address
	to, err := codec.ParseAddressBech32(nconsts.HRP, recipient)
	if err != nil {
		return fmt.Errorf("invalid recipient address: %w", err)
	}

	// Get asset ID
	assetID := ids.Empty // Assuming NAI is the native asset
	_, _, decimals, _, _, _, _, err := ncli.Asset(ctx, assetID, true)
	if err != nil {
		return fmt.Errorf("failed to get asset info: %w", err)
	}

	// Parse amount
	value, err := hutils.ParseBalance(amount, decimals)
	if err != nil {
		return fmt.Errorf("invalid amount: %w", err)
	}

	// Get sender address
	factory := auth.NewED25519Factory(privateKey)
	senderAddr := auth.NewED25519Address(privateKey.PublicKey())
	senderAddrStr := codec.MustAddressBech32(nconsts.HRP, senderAddr)

	// Ensure sufficient balance for transfer
	sendBal, err := ncli.Balance(ctx, senderAddrStr, assetID)
	if err != nil {
		return fmt.Errorf("failed to get balance: %w", err)
	}
	if value > sendBal {
		return fmt.Errorf("insufficient balance for transfer")
	}

	// Ensure sufficient balance for fees
	bal, err := ncli.Balance(ctx, senderAddrStr, ids.Empty)
	if err != nil {
		return fmt.Errorf("failed to get balance: %w", err)
	}

	// Generate transaction
	parser, err := ncli.Parser(ctx)
	if err != nil {
		return fmt.Errorf("failed to initialize parser: %w", err)
	}
	_, tx, maxFee, err := cli.GenerateTransaction(ctx, parser, nil, &actions.Transfer{
		To:    to,
		Asset: assetID,
		Value: value,
		Memo:  nil,
	}, factory)
	if err != nil {
		return fmt.Errorf("unable to generate transaction: %w", err)
	}
	if maxFee+value > bal {
		return fmt.Errorf("insufficient balance for fees")
	}
	if err := scli.RegisterTx(tx); err != nil {
		return fmt.Errorf("failed to register transaction: %w", err)
	}

	// Wait for transaction to be confirmed
	_, dErr, result, err := scli.ListenTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to listen for transaction: %w", err)
	}
	if dErr != nil {
		return fmt.Errorf("transaction failed: %w", dErr)
	}
	if !result.Success {
		return fmt.Errorf("transaction failed on-chain: %s", result.Output)
	}
	return nil
}
