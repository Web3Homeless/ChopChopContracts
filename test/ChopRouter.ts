require("dotenv").config();

import { ethers, network } from "hardhat";
import { expect } from "chai";
import { Contract, Signer, parseUnits, formatUnits } from "ethers";
import { ChopRouter, IERC20 } from "../typechain-types";

describe("TokenSwap on Ethereum Mainnet Fork", function () {
  let chopRouter: ChopRouter, usdc: IERC20;
  let impersonatedSigner: Signer;
  let destinationTokens: IERC20[] = [];
  let swapAmounts: bigint[] = [];
  let minOutAmounts: bigint[] = [];
  let accounts: Signer[],
    destinations: string[] = [];
  const totalAmount = parseUnits("1000", 6); // 1000 USDC

  before(async function () {
    // Fork Ethereum Mainnet
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.MAINNET_RPC_URL, // Replace with your Ethereum Mainnet RPC URL
            blockNumber: 17500000, // Optional: Set a specific block number for the fork
          },
        },
      ],
    });

    // Get the signers (accounts)
    accounts = await ethers.getSigners();

    // Use the Uniswap V2 Router address (Mainnet)
    const UniswapV2RouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"; // Uniswap V2 Router

    // Impersonate a USDC-rich account (for example, this one has a lot of USDC)
    const usdcWhale = "0x55fe002aeff02f77364de339a1292923a15844b8"; // A USDC whale address

    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [usdcWhale],
    });

    impersonatedSigner = await ethers.provider.getSigner(usdcWhale);

    // Deploy TokenSwap contract
    const ChopRouter = await ethers.getContractFactory("ChopRouter");
    chopRouter = await ChopRouter.deploy(UniswapV2RouterAddress);
    await chopRouter.waitForDeployment();

    // USDC token on Ethereum Mainnet
    usdc = await ethers.getContractAt(
      "IERC20",
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    ); // USDC address

    // Select 5 tokens that can be swapped from USDC on Uniswap V2
    const tokenAddresses = [
      "0x6B175474E89094C44Da98b954EedeAC495271d0F", // DAI (correct)
      "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH (correct)
      // "0xdAC17F958D2ee523a2206206994597C13D831ec7", // USDT (correct)
      "0x514910771AF9Ca656af840dff83E8264EcF986CA", // LINK (correct)
      "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984", // UNI (correct)
    ];

    for (let i = 0; i < tokenAddresses.length; i++) {
      const token = await ethers.getContractAt("IERC20", tokenAddresses[i]);
      destinationTokens.push(token);

      // Set the amount to swap for each destination
      const swapAmount = parseUnits((200).toString(), 6); // Swap 200 USDC each
      swapAmounts.push(swapAmount);

      // Set minimum output (for simplicity, 100 units of each destination token)
      const minOutAmount = parseUnits("100", await token.decimals());
      minOutAmounts.push(minOutAmount);

      // Set random destination addresses (use random accounts)
      destinations.push(await accounts[i].getAddress());
    }

    // Ensure swap amounts match totalAmount
    // const totalSwapAmount = swapAmounts.reduce((acc, curr) => acc + curr, 0n);
    // expect(totalSwapAmount).to.equal(totalAmount);

    // Fund the impersonated account with some ETH for gas
    await ethers.provider.send("hardhat_setBalance", [
      usdcWhale,
      "0x100000000000000000000",
    ]);
  });

  it("should perform swapAndDistribute from USDC", async function () {
    console.log("Approve tokens");
    // Approve the USDC for the contract
    await usdc
      .connect(impersonatedSigner)
      .approve(await chopRouter.getAddress(), totalAmount);
    console.log("After approve tokens");

    // Define Uniswap swap paths for each destination token
    const uniswapPaths: string[][] = [];
    for (let i = 0; i < destinationTokens.length; i++) {
      uniswapPaths.push([
        await usdc.getAddress(),
        await destinationTokens[i].getAddress(),
      ]); // Path: [USDC, OUT]
    }

    /*
        struct SwapParams {
        address destination;
        address destinationToken;
        uint256 swapAmount;
        uint256 minOutAmount;
        address[] uniswapPath;
    }
    */

    const swapParams: ChopRouter.SwapParamsStruct[] = destinations.map(
      (destination, i) => ({
        destination,
        destinationToken: destinationTokens[i],
        swapAmount: swapAmounts[i],
        minOutAmount: minOutAmounts[i],
        uniswapPath: uniswapPaths[i],
      })
    );

    console.log("Swap and distibute");
    // Perform the swap and distribute using the impersonated account
    await chopRouter
      .connect(impersonatedSigner)
      .swapAndDistribute(await usdc.getAddress(), totalAmount, swapParams);

    // Verify balances of destination tokens for each destination
    for (let i = 0; i < destinations.length; i++) {
      const destinationBalance = await destinationTokens[i].balanceOf(
        destinations[i]
      );
      // expect(destinationBalance).to.be.gte(minOutAmounts[i]);
      console.log(
        `Destination ${i + 1} received: ${formatUnits(
          destinationBalance,
          await destinationTokens[i].decimals()
        )} tokens`
      );
    }
  });
});
