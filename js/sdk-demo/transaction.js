// Copyright (C) 2024, Nuklai. All rights reserved.
// See the file LICENSE for licensing terms.

import {
  HyperchainSDK,
  actions,
  auth,
  codec,
  consts,
  utils
} from '@nuklai/hyperchain-sdk'

const DEFAULT_PRIVATE_KEY =
  'Mjsdj07tXw2p2pMHGwNPLc6dLSJpLBcvPLJSpk3fr9AbBX3jICl8Ka0MH1ieohaGnPGTjYjJ+9cNZ0gyPb8vpw=='
const DEFAULT_NUKLAI_RPC_URL = 'http://api-devnet.nuklaivm-dev.net:9650'
const DEFAULT_RECIPIENT =
  'nuklai1qpg4ecapjymddcde8sfq06dshzpxltqnl47tvfz0hnkesjz7t0p35d5fnr3'
const DEFAULT_AMOUNT = '0.00000001'
const CHAIN_ID = 'zepWp9PbeU9HLHebQ8gXkvxBYH5Bz4v8SoWXE6kyjjwNaMJfC'

const PRIVATE_KEY = process.argv[2] || DEFAULT_PRIVATE_KEY
const NUKLAI_RPC_URL = process.argv[3] || DEFAULT_NUKLAI_RPC_URL
const RECIPIENT = process.argv[4] || DEFAULT_RECIPIENT
const AMOUNT = process.argv[5] || DEFAULT_AMOUNT

const sdk = new HyperchainSDK({
  baseApiUrl: NUKLAI_RPC_URL,
  blockchainId: CHAIN_ID
})

async function testSDK() {
  console.log('Starting SDK tests...')

  // Testing Health Status
  try {
    console.log('Fetching Health Status...')
    const healthStatus = await sdk.rpcService.ping()
    console.log('Node Ping: ', healthStatus.success)

    if (!healthStatus.success) {
      console.error('Health Status check failed.')
      process.exit(1)
    }

    // Testing NAI Transfer with Ed25519 Keytype
    console.log('Creating Transfer Transaction...')
    // Set the private key for the sender address
    const authFactory = auth.getAuthFactory('ed25519', PRIVATE_KEY)

    const transfer = new actions.Transfer(
      RECIPIENT, // receiver address
      'NAI', // asset ID
      utils.parseBalance(parseFloat(AMOUNT), 9), // amount
      'Test Memo' // memo
    )

    const genesisInfo = {
      baseUnits: 1,
      storageKeyReadUnits: 5,
      storageValueReadUnits: 2,
      storageKeyAllocateUnits: 20,
      storageValueAllocateUnits: 5,
      storageKeyWriteUnits: 10,
      storageValueWriteUnits: 3,
      validityWindow: 60000
    }

    const actionRegistry = new codec.TypeParser()
    actionRegistry.register(
      consts.TRANSFER_ID,
      actions.Transfer.fromBytesCodec,
      false
    )
    const authRegistry = new codec.TypeParser()
    authRegistry.register(consts.BLS_ID, auth.BLS.fromBytesCodec, false)
    authRegistry.register(consts.ED25519_ID, auth.ED25519.fromBytesCodec, false)

    const { submit, txSigned, err } = await sdk.rpcService.generateTransaction(
      genesisInfo,
      actionRegistry,
      authRegistry,
      [transfer],
      authFactory
    )
    if (err) {
      throw err
    }

    await submit()
    console.log('Transaction ID:', txSigned.id().toString())
  } catch (error) {
    console.error('Failed to fetch Health Status:', error)
    process.exit(1)
  }
}

testSDK()
