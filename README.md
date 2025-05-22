# Infinity universal-router

## Running test

1. Install dependencies with `forge install`

2. Grab a RPC (eg. from nodereal) with history 
```bash
// testnet fork test for infinity, mainnet fork test for v2/v3 
export FORK_URL=https://bsc-mainnet.nodereal.io/v1/xxx
export TESTNET_FORK_URL=https://bsc-testnet.nodereal.io/v1/xxx
```

3. Run test with `forge test`

## Update dependencies

1. Run `forge update`

## Deploying 

Ensure `script/deployParameters/Deploy{chain}.s.sol` is updated 

```bash
// set rpc url
export RPC_URL=https://

// private key need to be prefixed with 0x
export PRIVATE_KEY=0x

// optional. Only set if you want to verify contract on explorer
export ETHERSCAN_API_KEY=xx

// replace with the respective chain eg. DeployArbitrum.s.sol:DeployArbitrum
forge script script/deployParameters/DeployArbitrum.s.sol:DeployArbitrum -vvv \
    --rpc-url $RPC_URL \
    --broadcast \
    --slow \
    --verify
``` 

Remember to call `.acceptOwnership()` to be the owner of universal router
