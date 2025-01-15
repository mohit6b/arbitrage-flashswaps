use ethers::prelude::*;
use std::convert::TryFrom;
use std::sync::Arc;
use dotenv::dotenv;
use std::env;
use std::fs;

mod encoding;

// Load ABIs from JSON files
abigen!(IWETH, "./abi/iweth.abi.json");
abigen!(IUSDC, "./abi/iusdc.abi.json");
abigen!(arbitrageContract, "./abi/arbitrage.abi.json");


#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
	dotenv().ok(); // Load environment variables from .env file

    // Connect to the Ethereum provider
	let provider_url = env::var("ETH_PROVIDER_URL").expect("ETH_PROVIDER_URL must be set");
    let provider = Provider::<Http>::try_from(provider_url)?; 
    let provider = Arc::new(provider);

    // Initialize wallet
	let private_key = env::var("WALLET_PRIVATE_KEY").expect("WALLET_PRIVATE_KEY must be set");
    let wallet: LocalWallet = private_key.parse()?;  
    let client = SignerMiddleware::new(provider.clone(), wallet);
    let client = Arc::new(client);

	// Initialize contract instances 
    let arbitrage_contract_address = env::var("ARBITRAGE_CONTRACT_ADDRESS")
        .expect("ARBITRAGE_CONTRACT_ADDRESS must be set")
        .parse::<Address>()?;
    let arbitrage_contract = arbitrageContract::new(arbitrage_contract_address, client.clone());

    let iweth_contract_address = env::var("IWETH_CONTRACT_ADDRESS")
        .expect("IWETH_CONTRACT_ADDRESS must be set")
        .parse::<Address>()?;
    let iweth_contract = IWETH::new(iweth_contract_address, client.clone());

    let iusdc_contract_address = env::var("IUSDC_CONTRACT_ADDRESS")
        .expect("IUSDC_CONTRACT_ADDRESS must be set")
        .parse::<Address>()?;
    let iusdc_contract = IUSDC::new(iusdc_contract_address, client.clone());


    // Define owner address and amount
    let owner = env::var("OWNER_ADDRESS")
        .expect("OWNER_ADDRESS must be set in the .env file")
        .parse::<Address>()?;
    let amount = U256::from(10).pow(U256::from(18)); // 1 ETHER

    // Approve transaction for WETH and USDC contracts
    let approve_call = iweth_contract.approve(arbitrage_contract_address, amount*2);
    let pending_tx = approve_call.send().await?;
    let approve_receipt = pending_tx.await?;
    println!("Approval transaction confirmed. Receipt: {:?}", 
        approve_receipt.unwrap().transaction_hash);

    // Wait a bit for the state to update
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    let approve_usdc_call = iusdc_contract.approve(arbitrage_contract_address, amount*2);
    let pending_usdc_tx = approve_usdc_call.send().await?;
    let approve_usdc_receipt = pending_usdc_tx.await?;
    println!("Approval transaction confirmed. Receipt: {:?}", 
    approve_usdc_receipt.unwrap().transaction_hash);

    // Wait a bit for the state to update
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    // Retrieve and print allowance for WETH and USDC
    let weth_allowance = iweth_contract.allowance(owner, arbitrage_contract_address).call().await?;
    println!("WETH Allowance of contract address {}: {}", arbitrage_contract_address, weth_allowance);

    let usdc_allowance = iusdc_contract.allowance(owner, arbitrage_contract_address).call().await?;
    println!("USDC Allowance of contract address {}: {}", arbitrage_contract_address, usdc_allowance);
    
	// Balance checks
    let init_bal_weth = iweth_contract.balance_of(owner).call().await?;
    println!("init_bal_weth of sender {}: {}", owner, init_bal_weth);
    let init_bal_usdc = iusdc_contract.balance_of(owner).call().await?;
    println!("init_bal_usdc of contract address {}: {}", owner, init_bal_usdc);

    // Call the encodingRequest function
    let encoded_bytes = encoding::encodingRequest();

    // Print the returned encoded bytes as a hex string
    println!("Encoded Arbitrage Request (Main): 0x{}", hex::encode(&encoded_bytes));

	// Call execute arbitrage function
    let approve_call = arbitrage_contract.execute_arbitrage(encoded_bytes.clone().into());
    let pending_tx = approve_call.send().await?;
    let approve_receipt = pending_tx.await?;
    println!("Approval transaction confirmed. Receipt: {:?}", 
        approve_receipt.unwrap().transaction_hash);

    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    let final_bal_weth = iweth_contract.balance_of(owner).call().await?;
    println!("final_bal_weth of sender {}: {}", owner, final_bal_weth);
    let final_bal_usdc = iusdc_contract.balance_of(owner).call().await?;
    println!("final_bal_usdc of contract address {}: {}", owner, final_bal_usdc);

    Ok(())
}
