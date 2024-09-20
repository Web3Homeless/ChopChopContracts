// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenSwap is ReentrancyGuard {
    address public uniswapRouter;

    constructor(address _uniswapRouter) {
        uniswapRouter = _uniswapRouter;
    }

    // Function to swap tokens and distribute to multiple destinations
    function swapAndDistribute(
        address inTokenAddress,
        uint256 totalAmount,
        address[] calldata destinations,
        address[] calldata destinationTokens,
        uint256[] calldata swapAmounts,
        uint256[] calldata minOutAmounts,
        address[][] calldata uniswapPaths
    ) external nonReentrant {
        require(
            destinations.length == destinationTokens.length &&
                destinations.length == swapAmounts.length &&
                destinations.length == minOutAmounts.length &&
                destinations.length == uniswapPaths.length,
            "Input length mismatch"
        );

        // Ensure the total of swap amounts matches the input amount
        uint256 totalSwapAmount = 0;
        for (uint256 i = 0; i < swapAmounts.length; i++) {
            totalSwapAmount += swapAmounts[i];
        }
        require(
            totalSwapAmount == totalAmount,
            "Swap amounts do not match total amount"
        );

        // Transfer inToken from sender to contract
        IERC20(inTokenAddress).transferFrom(
            msg.sender,
            address(this),
            totalAmount
        );
        IERC20(inTokenAddress).approve(uniswapRouter, totalAmount);

        uint256 aggregateAmountOut = 0;

        for (uint256 i = 0; i < destinations.length; i++) {
            uint256 tokenAmountOut = _swap(
                inTokenAddress,
                destinationTokens[i],
                swapAmounts[i],
                minOutAmounts[i],
                uniswapPaths[i]
            );

            require(
                tokenAmountOut >= minOutAmounts[i],
                "Output amount too low"
            );
            IERC20(destinationTokens[i]).transfer(
                destinations[i],
                tokenAmountOut
            );
            aggregateAmountOut += tokenAmountOut;
        }

        require(
            aggregateAmountOut >= totalAmount,
            "Total output less than input"
        );
    }

    // Internal function to swap tokens using Uniswap V2
    function _swap(
        uint256 amountIn,
        uint256 minAmountOut,
        address[] memory path
    ) internal returns (uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(uniswapRouter);

        uint256[] memory amountsOut = router.swapExactTokensForTokens(
            amountIn,
            minAmountOut, // User-defined minimum output amount
            path,
            address(this),
            block.timestamp + 1200
        );

        return amountsOut[amountsOut.length - 1]; // Return the amount received for the output token
    }
}
