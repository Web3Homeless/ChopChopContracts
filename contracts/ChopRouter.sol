// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract ChopRouter is ReentrancyGuard {
    address public uniswapRouter;

    constructor(address _uniswapRouter) {
        uniswapRouter = _uniswapRouter;
    }

    struct SwapParams {
        address destination;
        address destinationToken;
        uint256 swapAmount;
        uint256 minOutAmount;
        address[] uniswapPath;
    }

    // Function to swap tokens and distribute to multiple destinations
    function swapAndDistribute(
        address inTokenAddress,
        uint256 totalAmount,
        SwapParams[] memory swapParams
    ) external nonReentrant {
        // Ensure the total of swap amounts matches the input amount
        // uint256 totalSwapAmount = 0;
        // for (uint256 i = 0; i < swapAmounts.length; i++) {
        //     totalSwapAmount += swapAmounts[i];
        // }
        // require(
        //     totalSwapAmount == totalAmount,
        //     "Swap amounts do not match total amount"
        // );
        // Transfer inToken from sender to contract
        IERC20(inTokenAddress).transferFrom(
            msg.sender,
            address(this),
            totalAmount
        );
        IERC20(inTokenAddress).approve(uniswapRouter, totalAmount);
        // uint256 aggregateAmountOut = 0;
        for (uint256 i = 0; i < swapParams.length; i++) {
            SwapParams memory curParam = swapParams[i];
            uint256 tokenAmountOut = _swap(
                curParam.swapAmount,
                curParam.minOutAmount,
                curParam.uniswapPath
            );

            IERC20(curParam.destinationToken).transfer(
                curParam.destination,
                tokenAmountOut
            );
            // aggregateAmountOut += tokenAmountOut;
        }
        // require(
        //     aggregateAmountOut >= totalAmount,
        //     "Total output less than input"
        // );
    }

    // Internal function to swap tokens using Uniswap V2
    function _swap(
        uint256 amountIn,
        uint256 minAmountOut,
        address[] memory path
    ) internal returns (uint256) {
        console.log("Swap");
        IUniswapV2Router02 router = IUniswapV2Router02(uniswapRouter);

        uint256[] memory amountsOut = router.swapExactTokensForTokens(
            amountIn,
            // minAmountOut, // User-defined minimum output amount
            0,
            path,
            address(this),
            block.timestamp + 1200
        );

        return amountsOut[amountsOut.length - 1]; // Return the amount received for the output token
    }
}
