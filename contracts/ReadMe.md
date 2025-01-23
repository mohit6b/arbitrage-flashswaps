## Upgrades Made in the Updated Contract (Condensed)

1. Simplified routing logic by removing external router dependencies and interacting directly with pool addresses.
2. Improved gas efficiency using inline assembly for decoding swap parameters.
3. Dynamically set owner to msg.sender during each arbitrage transaction.
4. Added explicit functions for V2 and V3 flash swaps for advanced arbitrage.
5. Allowed dynamic fee adjustment for V3 swaps instead of hardcoding.
6. Optimized gas usage with unchecked increments in loops.
7. Systematically updated lastSwapOutput for accurate tracking of swap outputs.
8. Added profit validation with a require statement for minimum output.
9. Removed unnecessary debugging events to simplify the code.
10. Introduced IUniswapV2Pair and IUniswapV3Pool interfaces for direct pool interaction.
11. Modularized functions for better clarity and maintainability.
12. Added constants for MIN_SQRT_RATIO and MAX_SQRT_RATIO in V3 swaps.
13. Used inline assembly for efficient offset calculations.
