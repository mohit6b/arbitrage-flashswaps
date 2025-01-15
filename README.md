## Arbitrage

### Backend
#### Ethereum Smart Contract Interaction
main.rs is the simple rust implementation to interact with an Ethereum arbitrage smart contract using ethers-rs.

##### Setup
1. Clone repo and go to encoder folder: `cd encoder`
2. Install dependencies: `cargo build`
3. Set your Ethereum node URL and private key in .env
4. Run: `cargo run`

##### Features
1. Connect to Ethereum node
2. Interact with the arbitrage smart contract
3. Execute swaps between Uniswap V2/V3

#### Encoder
##### Arbitrage Contract Encoding and Decoding

This Rust program defines and encodes an arbitrage request for decentralized exchanges like UniswapV2 and UniswapV3, and decodes the request from its hexadecimal representation.

###### Key Components:
1. **ArbitrageHop**: Represents a hop in the arbitrage path, storing the pool type (UniswapV2/UniswapV3), direction (token0/token1), and pool address.
2. **ArbitrageRequest**: Encodes a full arbitrage request with input amount (WETH), minimum profit, and a list of hops.
3. **Encoding**: Converts the arbitrage request into a byte array and encodes it into a hex string.
4. **Decoding**: Decodes the hex string back into the original arbitrage request and prints out the input amount, minimum profit, and hop details for testing.
5. **Main**: Demonstrates encoding and decoding with a sample arbitrage request.

This encoder ensures efficient serialization and deserialization of arbitrage data for smart contract interactions.
