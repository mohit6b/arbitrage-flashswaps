## Arbitrage-Flashswaps

### Arbitrage Smart Contract

This Solidity smart contract facilitates atomic arbitrage between Uniswap V2 and Uniswap V3 pools in a single transaction. It takes a payload containing swap parameters, decodes the data, and executes sequential swaps. Key highlights of the contract:

1. **Decoding Payload**: The `executeArbitrage` function decodes the provided payload to extract swap parameters like pool type, token direction, and pool address for each hop.
2. **Dynamic Swap Execution**: It supports both Uniswap V2 and V3 swaps based on the pool type and token direction using `executeV2Swap` and `executeV3Swap` methods.
3. **Profit Validation**: After executing all swaps, it checks if the profit exceeds the specified minimum to ensure the arbitrage was successful.
4. **Token Approvals**: Tokens are dynamically approved and transferred to the respective pools during the swaps to facilitate seamless execution.
5. **WETH and USDC Tokens**: The contract assumes WETH as the starting and ending token, while USDC is involved in intermediate swaps.
6. **Gas Optimization**: The implementation minimizes gas usage by leveraging calldata for decoding and conditional swap execution.

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
