# Meridian — built on Arc

**Live app:** https://arcmeridian.netlify.app

A Uniswap V2-style automated market maker (AMM) decentralized exchange
running on Arc Testnet. Anyone can connect a wallet, swap test tokens, and
provide liquidity.

> Note: This project was originally announced as "Arc Meridian." In
> documentation and content going forward we use **"Meridian, built on
> Arc"**, in line with Circle's
> [brand guidelines](https://www.arc.io/brand-guidelines-and-partner-toolkit).

## Features

- Wallet connection (MetaMask / any EIP-1193-compatible wallet), with
  automatic silent reconnect on page refresh
- Automatic add/switch to the Arc Testnet network
- Token swaps — constant product formula (x·y=k), 0.3% fee, adjustable
  slippage tolerance, real-time price impact indicator
- Add / remove liquidity, with 25%/50%/75%/MAX quick-amount buttons
- 🤖 **Ask the Agent** — a lightweight, client-side intent-parsing layer
  that understands natural language ("swap 50 ARCA for ARCB", "add 100
  ARCA and 100 ARCB liquidity") and auto-fills the swap/liquidity form
- Pool stats (reserves, recent swap count) and a personal transaction
  history
- Toast notifications, empty-state illustrations, dark/light theme, EN/TR
  language support
- A faucet for our own test tokens, plus a shortcut to Circle's official
  USDC/EURC faucet
- Contract addresses and the token list are baked into the app — it works
  out of the box for anyone, no extra setup required

## Composability

Meridian's token list (via "add custom token" on the Faucet tab) is built
to support any ERC-20 / Arc-native asset. When assets expected to arrive
on Arc — like Maple Finance's syrupUSDC — become available on testnet, all
that's needed is adding their address; no code changes required.

## Deployed contracts (Arc Testnet, Chain ID 5042002)

| Contract | Address |
|---|---|
| ArcFactory | `0xd88551ac320493d045Bb7EC51311a0A9cD6f500e` |
| ArcRouter | `0x9352Bb36C93DC0A8638F250f77cbB5B9A32F7d04` |
| ARCA (test token) | `0x4E195F4Fc2678657414d6467EEA6432A30500231` |
| ARCB (test token) | `0x58B5f658133124aAD0B49eFF503296141c1dAd73` |
| USDC (Circle, official) | `0x3600000000000000000000000000000000000000` |
| EURC (Circle, official) | `0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a` |

## Project structure

```
arc-dex/
├── contracts/        Readable copy of the Solidity contracts
├── hardhat/           Hardhat project used for deployment
└── frontend/          index.html — the web UI (live on Netlify)
```

## Deploying your own contracts

```
cd hardhat
npm install
cp .env.example .env
# put your own private key in .env
npm run deploy
```

The script deploys the Factory, Router, and two test tokens in order and
prints the addresses to the terminal. Then update the `CONFIG` and
`TOKENS` constants in `frontend/index.html` with your own addresses and
upload it to a static hosting service (Netlify, Vercel, GitHub Pages).

## Verifying contracts on Arc Explorer

To have your source code show up as verified, you can use Hardhat's
verify plugin:

```
npm install --save-dev @nomicfoundation/hardhat-verify
```

Add Arc Explorer's (Blockscout-based) settings to `hardhat.config.js`:

```js
etherscan: {
  apiKey: { arcTestnet: "any-value" }, // Blockscout usually doesn't require a real key
  customChains: [{
    network: "arcTestnet",
    chainId: 5042002,
    urls: {
      apiURL: "https://testnet.arcscan.app/api",
      browserURL: "https://testnet.arcscan.app"
    }
  }]
}
```

Then, for each contract:

```
npx hardhat verify --network arcTestnet <CONTRACT_ADDRESS> [constructor args]
```

(Arc Explorer's exact API endpoint and requirements may change — check the
docs on `testnet.arcscan.app` for the latest.)

## Contract architecture

- **ArcERC20.sol** — the base ERC20 (parent of LP tokens and test tokens)
- **TestToken.sol** — a test token anyone can mint for free via `faucet()`
- **ArcFactory.sol** — creates and tracks liquidity pools (pairs) for
  token pairs
- **ArcPair.sol** — the core AMM logic: `mint`, `burn`, `swap` — constant
  product (x·y=k) formula, 0.3% fee
- **ArcRouter.sol** — the main contract the frontend interacts with:
  coordinates add/remove liquidity and swap operations with the pools

Inspired by Uniswap V2's general architecture; no external library
dependencies (e.g. OpenZeppelin).

## Security notes

- All state-changing functions (`mint`, `burn`, `swap`) are protected
  against reentrancy with a `lock` modifier.
- The `swap` function in `ArcPair.sol` enforces Uniswap V2's core
  invariant check, verifying that `k` does not decrease after fees
  (`balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 *
  FEE_DENOMINATOR^2`).
- The first liquidity provider has `MINIMUM_LIQUIDITY` worth of LP tokens
  permanently locked, following the standard Uniswap V2 mitigation
  against division-by-zero and "first depositor" attacks.
- **These contracts have not undergone an independent audit.** The scope
  is small and the architecture closely follows Uniswap V2, but a
  professional audit is strongly recommended before moving to mainnet or
  handling real value.

## Warning

These contracts are **unaudited** and intended for testnet / learning
purposes only. Do not use on mainnet or with real value.
