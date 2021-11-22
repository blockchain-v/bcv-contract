# bcv-contract

## Project setup
First, make sure to install the required dependencies:
```
npm install
```

## Contract Management
Put your contracts into `src/truffle/contracts`. To compile `cd` into
`src/truffle` and run
```
truffle compile
```

After successful compilation, run migration to deploy the contracts
```
truffle migrate --reset
```
The `--reset` flag will make sure the contracts are fully migrated even if previous
versions are already present on the network.

For local development simply open up Ganache with Quickstart. Alternatively, 
create a workspace in Ganache and import the `truffle-config.js` for more detailed
info within Ganache.

To test the contract, run the following command:
```
truffle test
```