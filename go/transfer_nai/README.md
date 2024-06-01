# Transfer NAI Tokens

This Go program transfers 0.0001 NAI tokens to a specified recipient address using a given private key.

## Prerequisites

- Go 1.21 or later installed
- A valid private key in base64 format

## Building the Program

Clone the repository and navigate to the program directory:

```sh
git clone https://github.com/kpachhai/nuklai-scripts.git
cd nuklai-scripts/go/transfer_nai
```

Build the Go program:

```sh
go build -o transfer_nai
```

## Running the Program

You can run the program with:

```sh
./transfer_nai <base64_encoded_private_key> <nuklaiRPCURL> <recipient> <amount>
```

Replace <base64_encoded_private_key>, <nuklaiRPCURL>, <recipient>, and <amount> with your actual values.
