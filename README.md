# Example BEP20 Token (BabyDoge Clone Style) - By Frenki

This repository contains an example Solidity smart contract for a BEP20 token deployed on the Binance Smart Chain (BSC). The contract aims to replicate the core mechanics often found in tokens like BabyDogeCoin, including:

*   **Reflection/Static Rewards:** Holders receive passive rewards directly to their wallets from transaction fees.
*   **Automatic Liquidity Pool (Auto-LP):** A portion of transaction fees is automatically added to the PancakeSwap liquidity pool.
*   **Transaction Fees:** Configurable fees on transfers to fund reflections and liquidity.

**Watermark:** This code includes a watermark crediting **Frenki** as the initial creator of this specific example clone.

## Features

*   BEP20 Standard Compliance
*   Static Rewards (Reflection) to holders
*   Automatic Liquidity Generation via PancakeSwap V2 Router interaction
*   Configurable Transaction Fees (Tax Fee for Reflection, Liquidity Fee for LP)
*   Ability to Exclude addresses from Fees
*   Ability to Exclude addresses from Rewards (Reflection)
*   `Ownable` Access Control (Deployer manages settings)
*   Swap and Liquify mechanism to prevent contract token balance from growing indefinitely
*   Rescue functions for accidentally sent BNB or other BEP20 tokens (Owner only)

## Prerequisites

*   Basic understanding of Solidity, Smart Contracts, and the BEP20 standard.
*   A development environment like Remix IDE, Hardhat, or Truffle.
*   Node.js and npm/yarn (if using Hardhat/Truffle).
*   A crypto wallet (e.g., MetaMask) configured for Binance Smart Chain (Mainnet and Testnet).
*   Testnet BNB for deployment and testing on BSC Testnet.

## Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/frenkiofficial/Crypto-Token-Example.git
    cd Crypto-Token-Example
    ```

2.  **Install Dependencies:**
    This contract uses OpenZeppelin Contracts. If you are using Hardhat or Truffle, install them:
    ```bash
    npm install @openzeppelin/contracts
    # or
    yarn add @openzeppelin/contracts
    ```
    (If using Remix, you can usually import directly via GitHub URL as shown in the code).

## Configuration (Before Deployment)

Open the `ExampleToken.sol` file and modify the following parameters according to your needs:

1.  **Token Details:**
    *   `_name`: Set your desired token name (e.g., `"My Awesome Token"`).
    *   `_symbol`: Set your token symbol (e.g., `"MAT"`).
    *   `_decimals`: Set the token decimals (Default is `9`, similar to BabyDoge. `18` is also common).

2.  **Total Supply:**
    *   `_tTotal`: Adjust the initial total supply in the `constructor`. Remember to account for the decimals (e.g., `1000000 * (10**uint256(_decimals))` for 1 million tokens).

3.  **Fees:**
    *   `_taxFee`: The percentage of each transaction redistributed to holders (Default: `5`).
    *   `_liquidityFee`: The percentage of each transaction sent to the contract for Auto-LP (Default: `5`).
    *   **Note:** You can change these after deployment using the `setFees(uint256 newTaxFee, uint256 newLiquidityFee)` function (callable by the owner). Ensure `_taxFee + _liquidityFee` does not exceed a reasonable limit (e.g., 25% enforced in `setFees`).

4.  **PancakeSwap Router Address (CRITICAL):**
    *   In the `constructor`, the `routerAddress` parameter must be set correctly during deployment.
        *   **BSC Mainnet Router V2:** `0x10ED43C718714eb63d5aA57B78B54704E256024E`
        *   **BSC Testnet Router V2:** `0xD99D1c33F9fC3444f8101754aBC46c52416550D1`
    *   **Ensure you use the correct address for the network you are deploying to!** The contract creates the PancakeSwap pair using this router's factory address.

5.  **Swap & Liquify Threshold:**
    *   `numTokensSellToAddToLiquidity`: The minimum number of tokens the *contract itself* must hold to trigger the automatic swap (to BNB) and add liquidity function. Adjust this value (without decimals initially, it gets multiplied by `10**_decimals` in the contract). A smaller value triggers more often (more gas cost), a larger value less often. The default is `500,000` (before decimals). Modify this using `setNumTokensSellToAddToLiquidity(uint256 _numTokensNoDecimals)` after deployment if needed.

## Deployment

1.  **Compile:** Use a Solidity compiler compatible with `pragma solidity ^0.8.4;`. Ensure there are no compilation errors.
2.  **Deploy:** Use Remix, Hardhat, Truffle, or another deployment tool.
    *   Select the `ExampleToken` contract.
    *   **IMPORTANT:** When deploying, you MUST provide the correct **PancakeSwap V2 Router address** for your target network (Testnet or Mainnet) as the constructor argument.
    *   Deploy to your chosen network (BSC Testnet recommended first). The deployer wallet will become the contract `owner`.

## Usage After Deployment

1.  **Verify Contract:** Verify your contract source code on BscScan (or Testnet BscScan) for transparency.
2.  **Add Initial Liquidity:** **This contract does NOT automatically add the very first liquidity.** The owner (deployer) must manually add the initial liquidity pool on PancakeSwap (e.g., YourToken/BNB pair) using a portion of the tokens they received at deployment and some BNB. This is necessary for trading to begin. Consider locking the initial LP tokens for community trust.
3.  **Manage Settings (Owner):** The owner can use functions like:
    *   `setFees(taxFee, liquidityFee)`: Adjust transaction fees.
    *   `excludeFromFee(address account)` / `includeInFee(address account)`: Manage fee exemptions.
    *   `excludeFromReward(address account)` / `includeInReward(address account)`: Manage reward (reflection) exemptions. **Note:** The PancakeSwap Pair address is excluded from rewards by default and should remain so.
    *   `setSwapAndLiquifyEnabled(bool _enabled)`: Enable/disable the auto-LP feature.
    *   `setNumTokensSellToAddToLiquidity(numTokens)`: Change the auto-LP trigger threshold.
    *   `transferOwnership(newOwner)`: Transfer control of the contract.
    *   `renounceOwnership()`: **(Use with extreme caution!)** Permanently give up ownership.
4.  **Interact:** Users can now transfer, buy, and sell the token (if liquidity exists), benefiting from reflections and contributing to auto-LP via transaction fees.

## Testing (Crucial!)

**ALWAYS test thoroughly on the BSC Testnet before deploying to Mainnet.**

*   Perform transfers between different wallets.
*   Test transfers involving wallets excluded/included from fees/rewards.
*   Simulate buying and selling on PancakeSwap Testnet.
*   Verify that reflections are being distributed to holders (balances should increase over time with volume).
*   Trigger the `swapAndLiquify` function by performing enough transactions/volume so the contract accumulates tokens above the threshold. Verify that it successfully swaps tokens for BNB and adds liquidity.
*   Test all owner-specific functions.

## 🚨 Disclaimer 🚨

*   **This code is provided AS IS, for educational and example purposes only.**
*   **It has NOT been professionally audited.** Deploying unaudited smart contracts to the Mainnet is extremely risky.
*   **Use at your own risk.** The author (Frenki) assumes no responsibility for any losses or damages caused by the use of this code.
*   Smart contract development is complex. Bugs or vulnerabilities can lead to irreversible loss of funds.
*   Features like reflection and auto-LP involve multiple contract interactions and can be gas-intensive.
*   **ALWAYS conduct thorough testing on a Testnet and consider obtaining a professional security audit before deploying any token intended for public use or involving real funds.**

## Need Custom Blockchain Development?

If you require a custom smart contract, a complete token launch, a DApp (Decentralized Application), or other blockchain-related development services, feel free to reach out to me (Frenki)!

*   **GitHub:** [https://github.com/frenkiofficial](https://github.com/frenkiofficial)
*   **Hugging Face:** [https://huggingface.co/frenkiofficial](https://huggingface.co/frenkiofficial)
*   **Telegram:** [https://t.me/FrenkiOfficial](https://t.me/FrenkiOfficial)
*   **Twitter:** [https://twitter.com/officialfrenki](https://twitter.com/officialfrenki)
*   **Fiverr:** [https://www.fiverr.com/frenkimusic/](https://www.fiverr.com/frenkimusic/)

## License

This example code is released under the MIT License. See the `LICENSE` file (or check the SPDX identifier in the `.sol` file) for details.