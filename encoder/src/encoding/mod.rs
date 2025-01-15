use ethers::types::{H160, U256};
use bytes::{BytesMut, BufMut};

// mod contract_interaction;

// Struct to represent a single hop in the arbitrage
struct ArbitrageHop {
    pool_type: bool,       // 0 for UniswapV2, 1 for UniswapV3
    direction: bool,       // 0 for selling token0, 1 for selling token1
    pool_address: H160,    // Address of the pool
}

// Struct to represent the full arbitrage request
struct ArbitrageRequest {
    input_amount: U256,    // Input amount of WETH (128 bits)
    min_profit: U256,      // Minimum expected profit (128 bits)
    hops: Vec<ArbitrageHop>, // Hops in the arbitrage
}

impl ArbitrageRequest {
    // Encode the arbitrage request into bytes
    fn encode(&self) -> Vec<u8> {
        let mut encoded = BytesMut::with_capacity(32 + self.hops.len() * 21);

        // Add input_amount and min_profit (each as 128 bits, padded to 16 bytes)
        let mut input_amount_bytes = [0u8; 32];
        self.input_amount.to_big_endian(&mut input_amount_bytes);
        encoded.put_slice(&input_amount_bytes[16..]);

        let mut min_profit_bytes = [0u8; 32];
        self.min_profit.to_big_endian(&mut min_profit_bytes);
        encoded.put_slice(&min_profit_bytes[16..]);


        // Encode each hop
        for hop in &self.hops {
            // First byte: selector (1 bit) + direction (1 bit), padded to 8 bits
            let selector_and_direction = ((hop.pool_type as u8) << 1) | (hop.direction as u8);
            encoded.put_u8(selector_and_direction);

            // Add the pool address (160 bits)
            encoded.put_slice(hop.pool_address.as_bytes());
        }

        encoded.to_vec()
    }
}

fn decode(encoded: &str) {
    // Remove the "0x" prefix
    let encoded_bytes = hex::decode(&encoded[2..]).unwrap();

    // Extract the input amount (first 16 bytes)
    let input_amount = U256::from_big_endian(&encoded_bytes[0..16]);

    // Extract the minimum profit (next 16 bytes)
    let min_profit = U256::from_big_endian(&encoded_bytes[16..32]);

    println!("Input Amount (WETH): {}", input_amount);
    println!("Minimum Profit (WETH): {}", min_profit);

    // Decode the hops (remaining bytes, 21 bytes per hop)
    let mut offset = 32;
    let mut hops = Vec::new();
    while offset < encoded_bytes.len() {
        // First byte: selector and direction
        let selector_and_direction = encoded_bytes[offset];
        let pool_type = (selector_and_direction & 0b10) != 0; // Second bit
        let direction = (selector_and_direction & 0b01) != 0; // First bit

        // Next 20 bytes: pool address
        let pool_address = H160::from_slice(&encoded_bytes[offset + 1..offset + 21]);

        hops.push((pool_type, direction, pool_address));
        offset += 21;
    }

    // Print hop data
    for (i, hop) in hops.iter().enumerate() {
        println!(
            "Hop {}: Pool Type: {}, Direction: {}, Pool Address: {}",
            i + 1,
            if hop.0 { "UniswapV3" } else { "UniswapV2" },
            if hop.1 { "Selling token1" } else { "Selling token0" },
            hop.2
        );
    }
}

pub fn encodingRequest() -> Vec<u8> {
    // Define the arbitrage request
    let arbitrage_request = ArbitrageRequest {
        input_amount: U256::from_dec_str("1000000000000000000").unwrap(), // 1 ETH in wei
        min_profit: U256::from_dec_str("1000000000000000").unwrap(), // 0.001 ETH in wei
        hops: vec![
            ArbitrageHop {
                pool_type: false, // UniswapV2
                direction: true, // Selling token0
                pool_address: "0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc"
                    .parse::<H160>()
                    .unwrap(),
            },
            ArbitrageHop {
                pool_type: true, // UniswapV3
                direction: false, // Selling token1
                pool_address: "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640"
                    .parse::<H160>()
                    .unwrap(),
            },
            // ArbitrageHop {
            //     pool_type: true, // UniswapV3
            //     direction: false, // Selling token0
            //     pool_address: "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640"
            //         .parse::<H160>()
            //         .unwrap(),
            // },
            // ArbitrageHop {
            //     pool_type: false, // UniswapV2
            //     direction: false, // Selling token0
            //     pool_address: "0x397FF1542f962076d0BFE58eA045FfA2d347ACa0"
            //         .parse::<H160>()
            //         .unwrap(),
            // },
        ],
    };

    // Encode the request
    let encoded_bytes = arbitrage_request.encode();

    // Convert the encoded bytes into a hex string
    let encoded_hex = format!("0x{}", hex::encode(&encoded_bytes));

    // Print the encoded arbitrage request
    println!("Encoded Arbitrage Request: {}", encoded_hex);
    
    // // Decode the encoded output
    // decode(&encoded_hex);

    encoded_bytes
}