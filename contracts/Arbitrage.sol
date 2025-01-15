// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "hardhat/console.sol";

contract Arbitrage {
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;  
    address constant SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //token in
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //token out


    // Interfaces to interact with Uniswap V2, V3, WETH & ERC20 tokens
    IUniswapV2Router private v2_router = IUniswapV2Router(UNISWAP_V2_ROUTER);
    ISwapRouter02 private v3_router = ISwapRouter02(SWAP_ROUTER_02);
    IWETH private weth = IWETH(WETH);
    IERC20 private usdc = IERC20(USDC);
    uint256 lastSwapOutput;

    struct SwapParams {
        address pool;
        bool isV3;
        bool sellToken0; //token0 = WETH, token1 = USDC
    }

    // Main entry point for atomic arbitrage
    function executeArbitrage(bytes calldata payload) external {
        // Decode initial parameters
        uint128 inputAmount = uint128(bytes16(payload[0:16]));
        uint128 minProfit = uint128(bytes16(payload[16:32]));

        // uint256 initialBalance = IERC20(WETH).balanceOf(address(this));
        // console.log("4. init Balance:", initialBalance);   

        lastSwapOutput = inputAmount;
        // Calculate the number of hops
        uint256 hopCount = (payload.length - 32) / 21;
        // SwapParams memory params = new SwapParams[](hopCount);

        console.log("1: inputAmount:", inputAmount);
        console.log("2: minProfit:", minProfit);

        for (uint256 i = 0; i < hopCount; i++) {
            uint256 offset = 32 + (i * 21);

            SwapParams memory params = this.decodeNextSwap(payload, offset);
            console.log("params.pool:", params.pool);
            console.log("params.isV3:", params.isV3);
            console.log("params.sellToken0:", params.sellToken0);

            this.executeSwap(params, lastSwapOutput, 1);
        }

        // Verify profit
        uint256 finalBalance = IERC20(WETH).balanceOf(address(this));
        console.log("finalBalance", finalBalance);

        // require(finalBalance >= initialBalance + minProfit, "Insufficient profit");
        
        // // 2 hops: v2-> v3, 2 hops: v2 -> v3

        // // Execute first swap
        // SwapParams memory firstSwap = this.decodeNextSwap(swapData, 0);
        // console.log("SwapParams.pool:", firstSwap.pool);
        // console.log("SwapParams.isV3:", firstSwap.isV3);
        // console.log("SwapParams.sellToken0:", firstSwap.sellToken0);

        // this.executeSwap(firstSwap, inputAmount, 1);
        
        // // Execute remaining swaps
        // uint256 offset = 21; // 1 + 1 + 160 bits = 21 bytes - 1 hop
        // while (offset < swapData.length) {
        //     SwapParams memory params = this.decodeNextSwap(swapData, offset);

        //     console.log("params.pool:", params.pool);
        //     console.log("params.isV3:", params.isV3);
        //     console.log("params.sellToken0:", params.sellToken0);

        //     this.executeSwap(params, lastSwapOutput, 1);
        //     offset += 21;
        // }
        
        
    }


    function decodeNextSwap(bytes calldata payload, uint256 offset) external pure returns (SwapParams memory) {
        require(offset + 21 <= payload.length, "Invalid data length");
        
        bool isV3;
        bool sellToken0;
        address pool;

        // First byte contains poolType and direction
        uint8 selectorAndDirection = uint8(payload[offset]); //uint8(payload[offset]);
        bool poolType = (selectorAndDirection & 0x02) != 0; // Second bit
        bool direction = (selectorAndDirection & 0x01) != 0; // First bit

        // Next 20 bytes for poolAddress
        address poolAddress;
        assembly {
            poolAddress := shr(96, calldataload(add(payload.offset, add(offset, 1))))
        }

        console.log("pool addr:", poolAddress);
        
        console.log("params.pool:", pool);
        console.log("params.isV3:", isV3);
        console.log("params.sellToken0:", sellToken0);

        return SwapParams({
            pool: poolAddress,
            isV3: poolType,
            sellToken0: direction
        });
    }


    function executeSwap(SwapParams memory params, uint256 amountIn, uint256 amountOutMin) external {
        if (params.isV3) {
            this.executeV3Swap(params, amountIn, amountOutMin);
        } else {
            this.executeV2Swap(params, amountIn, amountOutMin);
        }
    }

    // Swap WETH to USDC: The start/end token is always WETH.  

    // no need for uint256 amountIn as it is coming from params
    function executeV2Swap(SwapParams memory params, uint256 amountIn, uint256 amountOutMin) external returns (uint256 amountOut) {
        
        address[] memory path;
        path = new address[](2);

        IERC20 tokenIn = params.sellToken0 ? weth : usdc;
        path[0] = params.sellToken0 ? WETH : USDC;
        path[1] = params.sellToken0 ? USDC : WETH;

        console.log("V2 tokenIn", path[0]);
        console.log("V2 tokenOut", path[1]);

        // Transfer and approve tokens

        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        console.log("TransferFromWorked");
        tokenIn.approve(address(v2_router), amountIn);
        uint256 allowance2 = tokenIn.allowance(msg.sender, address(v3_router));
        console.log("Allowance by msg.sender to arbitrage contract in V2: ", allowance2);


        uint256[] memory amounts = v2_router.swapExactTokensForTokens(
            amountIn, amountOutMin, path, msg.sender, block.timestamp
        );

        // For WETH -> USDC => amounts[0] = WETH amount, amounts[1] = USDC amount 
        // For USDC -> WETH => amounts[0] = WETH amount, amounts[1] = USDC amount 
        console.log("return amount V2:", amounts[1]);
        lastSwapOutput = amounts[1];
        return amounts[1];

    }

    function executeV3Swap(SwapParams memory params, uint256 amountIn, uint256 amountOutMin) external returns (uint256 amountOut) {
        address[] memory path;
        path = new address[](2);

        IERC20 tokenIn = params.sellToken0 ? weth : usdc;
        path[0] = params.sellToken0 ? WETH : USDC;
        path[1] = params.sellToken0 ? USDC : WETH;
        console.log("tokenIn", path[0]);
        console.log("tokenOut", path[1]);
        // Transfer and approve tokens
        tokenIn.approve(address(this), amountIn);
        uint256 allowance1 = tokenIn.allowance(msg.sender, address(this));
        console.log("Allowance by msg.sender to arbitrage contract in V3: ", allowance1);


        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        console.log("TransferFromWorked");
        tokenIn.approve(address(v3_router), amountIn);
        uint256 allowance2 = tokenIn.allowance(msg.sender, address(v3_router));
        console.log("Allowance by msg.sender to arbitrage contract in V2: ", allowance2);


        ISwapRouter02.ExactInputSingleParams memory parameter = ISwapRouter02
            .ExactInputSingleParams({
            tokenIn: path[0],
            tokenOut: path[1],
            fee: 3000,
            recipient: msg.sender,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        uint256 amount = v3_router.exactInputSingle(parameter);

        // For WETH -> USDC => amounts[0] = WETH amount, amounts[1] = USDC amount 
        // For USDC -> WETH => amounts[0] = WETH amount, amounts[1] = USDC amount 
        // params.amountIn = amount;
        console.log("return amount V3:", amount);
        lastSwapOutput = amount;
        return amount;
        
    }
}
    
interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        returns (uint256 amountIn);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount)
        external
        returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}