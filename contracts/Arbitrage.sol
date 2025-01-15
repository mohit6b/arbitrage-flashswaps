// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

/**
 * @title Arbitrage Contract
 * @notice Facilitates arbitrage trading between Uniswap V2 and V3 pools using WETH and USDC
 */
contract arbitrage {
    // Constants for router and token addresses
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //token in
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //token out

    // Events for logging key actions
    event TestWETHTransfer(address, address, uint256);
    event TestApproval(address, uint256);
    event PATH(address[]);
    event AMOUNTS(uint256[]);
    event InputEvent(address, address, uint256);

    // Interfaces for interacting with Uniswap and token contracts
    IUniswapV2Router private v2_router = IUniswapV2Router(UNISWAP_V2_ROUTER);
    ISwapRouter02 private v3_router = ISwapRouter02(SWAP_ROUTER_02);
    IWETH private weth = IWETH(WETH);
    IERC20 private usdc = IERC20(USDC);
    uint256 lastSwapOutput; // Holds the result of the last swap
    address owner; // Tracks the owner of the arbitrage call

    // Structure defining swap parameters
    struct SwapParams {
        address pool; // Address of the liquidity pool
        bool isV3; // Indicates whether the pool is Uniswap V3
        bool sellToken0; // Indicates the token being sold (true: token0, false: token1)
    }

    /**
     * @notice Executes a multi-hop arbitrage trade based on the provided payload
     * @param payload Encoded input data containing amounts, minimum profit, and swap parameters
     */
    function executeArbitrage(bytes calldata payload) external {
        // Decode initial parameters
        uint128 inputAmount = uint128(bytes16(payload[0:16]));
        uint128 minProfit = uint128(bytes16(payload[16:32]));

        owner = msg.sender; // Set the caller as the owner for this transaction
        lastSwapOutput = inputAmount; // Initialize swap output
        uint256 hopCount = (payload.length - 32) / 21; // Calculate the number of hops

        // Process each swap
        for (uint256 i = 0; i < hopCount; i++) {
            uint256 offset = 32 + (i * 21);

            SwapParams memory params = decodeNextSwap(payload, offset);
            executeSwap(params, lastSwapOutput, 1);
        }

        // Ensure the trade meets the minimum profit requirement
        require(lastSwapOutput >= minProfit + inputAmount, "Insufficient profit");
    }

    /**
     * @notice Decodes swap parameters from the payload
     * @param payload Encoded input data
     * @param offset Offset for reading swap parameters
     * @return Decoded SwapParams struct
     */
    function decodeNextSwap(bytes calldata payload, uint256 offset) internal pure returns (SwapParams memory) {
        require(offset + 21 <= payload.length, "Invalid data length");
        
        // First byte contains poolType and direction
        uint8 selectorAndDirection = uint8(payload[offset]); //uint8(payload[offset]);
        bool poolType = (selectorAndDirection & 0x02) != 0; // Extracts pool type (2nd bit)
        bool direction = (selectorAndDirection & 0x01) != 0; // Extracts direction (1st bit)

        // Decode the pool address from the next 20 bytes
        address poolAddress;
        assembly {
            poolAddress := shr(96, calldataload(add(payload.offset, add(offset, 1))))
        }

        return SwapParams({
            pool: poolAddress,
            isV3: poolType,
            sellToken0: direction
        });
    }

    /**
     * @notice Executes a swap operation based on the provided parameters
     * @param params Swap parameters
     * @param amountIn Input token amount for the swap
     * @param amountOutMin Minimum output amount required from the swap
     */
    function executeSwap(SwapParams memory params, uint256 amountIn, uint256 amountOutMin) internal {
        if (params.isV3) {
            executeV3Swap(params, amountIn, amountOutMin);
        } else {
            executeV2Swap(params, amountIn, amountOutMin);
        }
    }

    /**
     * @notice Executes a Uniswap V2 swap
     * @param params Swap parameters
     * @param amountIn Input token amount
     * @param amountOutMin Minimum output amount required
     * @return amountOut The actual output amount received
     */
    function executeV2Swap(SwapParams memory params, uint256 amountIn, uint256 amountOutMin) internal returns (uint256 amountOut) {
        // Determine the token path for the swap
        address[] memory path;
        path = new address[](2);

        IERC20 tokenIn = params.sellToken0 ? weth : usdc;
        path[0] = params.sellToken0 ? WETH : USDC;
        path[1] = params.sellToken0 ? USDC : WETH;


        // Transfer and approve tokens
        tokenIn.transferFrom(owner, address(this), amountIn);
        tokenIn.approve(address(v2_router), amountIn);

        // Set up the swap parameters and execute the swap
        uint256[] memory amounts = v2_router.swapExactTokensForTokens(
            amountIn, amountOutMin, path, msg.sender, block.timestamp
        );

        // For WETH -> USDC => amounts[0] = WETH amount, amounts[1] = USDC amount 
        // For USDC -> WETH => amounts[0] = WETH amount, amounts[1] = USDC amount 
        lastSwapOutput = amounts[1];
        return amounts[1];

    }

    /**
     * @notice Executes a Uniswap V3 swap
     * @param params Swap parameters
     * @param amountIn Input token amount
     * @param amountOutMin Minimum output amount required
     * @return amountOut The actual output amount received
     */
    function executeV3Swap(SwapParams memory params, uint256 amountIn, uint256 amountOutMin) internal returns (uint256 amountOut) {
        address[] memory path;
        path = new address[](2);

        // Determine the token path for the swap
        IERC20 tokenIn = params.sellToken0 ? weth : usdc;
        path[0] = params.sellToken0 ? WETH : USDC;
        path[1] = params.sellToken0 ? USDC : WETH;

        // Transfer and approve tokens
        tokenIn.transferFrom(owner, address(this), amountIn);
        tokenIn.approve(address(v3_router), amountIn);

        // Set up the swap parameters and execute the swap
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
