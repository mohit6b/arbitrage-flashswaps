// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/**
 * @title Arbitrage Contract
 * @notice Facilitates arbitrage trading between Uniswap V2 and V3 pools using WETH and USDC
 */
contract ArbitrageUpdated {
    // Constants for router and token addresses
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint160 private constant MIN_SQRT_RATIO = 4295128739;
    uint160 private constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;

    // Interfaces
    IWETH private immutable weth = IWETH(WETH);
    IERC20 private immutable usdc = IERC20(USDC);

    uint256 private lastSwapOutput;
    address private owner;

    struct SwapParams {
        address pool;
        bool isV3;
        bool sellToken0;
    }

    function executeArbitrage(bytes calldata payload) external {
        uint128 inputAmount = uint128(bytes16(payload[0:16]));
        uint128 minProfit = uint128(bytes16(payload[16:32]));

        owner = msg.sender;
        lastSwapOutput = inputAmount;
        uint256 hopCount = (payload.length - 32) / 21;

        for (uint256 i = 0; i < hopCount; ) {
           uint256 offset;
           assembly {
              offset := add(32, mul(i, 21)) // Calculate offset directly
           }

          SwapParams memory params = decodeNextSwap(payload, offset);
          executeSwap(params, lastSwapOutput, 1);
          unchecked {
                i++;
            }
        }

        require(lastSwapOutput >= minProfit + inputAmount, "Insufficient profit");
    }

    function decodeNextSwap(bytes calldata payload, uint256 offset) internal pure returns (SwapParams memory) {
        uint8 selectorAndDirection = uint8(payload[offset]);
        address poolAddress;

        assembly {
            poolAddress := shr(96, calldataload(add(payload.offset, add(offset, 1))))
        }

        return SwapParams({
            pool: poolAddress,
            isV3: (selectorAndDirection & 0x02) != 0,
            sellToken0: (selectorAndDirection & 0x01) != 0
        });
    }

    function executeSwap(SwapParams memory params, uint256 amountIn, uint256 amountOutMin) internal {
        if (params.isV3) {
            lastSwapOutput = executeV3FlashSwap(params, amountIn);
        } else {
            lastSwapOutput = executeV2FlashSwap(params, amountIn, amountOutMin);
        }
    }

    function executeV2FlashSwap(SwapParams memory params, uint256 wethAmount, uint256 amountOutMin) internal returns (uint256) {
        
        address pairAddress = params.pool;
        require(pairAddress != address(0), "No pair exists");

        bytes memory data = abi.encode(params.sellToken0 ? WETH : USDC, owner);

        IUniswapV2Pair(pairAddress).swap(
            params.sellToken0 ? 0 : wethAmount,
            params.sellToken0 ? wethAmount : 0,
            address(this),
            data
        );

        return wethAmount - amountOutMin; // Return output after fees
    }

    function executeV3FlashSwap(SwapParams memory params, uint256 amountIn) internal returns (uint256) {
       IERC20 tokenIn = params.sellToken0 ? weth : usdc;
       IERC20 tokenOut = params.sellToken0 ? usdc : weth;
       bool zeroForOne = weth < usdc;
        // 0 -> 1 => sqrt price decrease
        // 1 -> 0 => sqrt price increase
        uint160 sqrtPriceLimitX96 =
            zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;

        bytes memory data = abi.encode(
            msg.sender, params.pool, 3000, tokenIn, tokenOut, amountIn, zeroForOne
        );

        (int256 amount0, int256 amount1) = IUniswapV3Pool(params.pool).swap({
            recipient: address(this),
            zeroForOne: zeroForOne,
            amountSpecified: int256(amountIn),
            sqrtPriceLimitX96: sqrtPriceLimitX96,
            data: data
        });

        return uint256(amount1);
    }
     
}

interface IUniswapV2Pair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
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
