# Lockless

**Liquid veMEZO for Mezo Earn.** Lock MEZO forever, stay liquid, earn MUSD.

Lockless holds one permanent veMEZO lock. Anyone can add MEZO to it, or merge an existing veMEZO lock into it, and receive **stMEZO** one for one. stMEZO is a normal token you can trade or stake at any time. Every epoch a keeper votes the lock for the boost gauges that pay the most per vote, harvests the incentives, turns them into MUSD and streams them to stMEZO stakers.

Built for the Mezo Buildathon, Track 1 (DeFi): a staking derivative for MEZO that plugs straight into Mezo's vote-escrow system.

## Why

- **veMEZO is a 4-year lock.** It only earns if the holder votes on boost gauges and claims every week. Most holders cannot do that well, and nobody can leave early.
- **Holders are paying about 43% to get out.** A desk on mainnet (`0xaDCa5c0f269730d2f88EE2F741CD1D5e57960742`) buys veMEZO locks for 50% to 60% of their MEZO. In 40 sales, sellers gave up about 296,500 locked MEZO for about 167,600 MEZO.
- **The market is large.** About 281.7M MEZO, roughly a quarter of supply, sits in veMEZO across 1,374 holders.

With Lockless, a 1,000 MEZO lock becomes 1,000 stMEZO instead of 600 MEZO from the desk, and keeps earning.

## How it works

```
 MEZO or a veMEZO lock
          │
          ▼
 ┌─────────────────┐   mints 1:1   ┌─────────┐   stake   ┌────────────────┐
 │  LocklessVault  │ ────────────▶ │ stMEZO  │ ────────▶ │ StMEZOStaking  │
 │ (master veMEZO) │               └─────────┘           └────────────────┘
 └─────────────────┘                                              ▲
     │ keeper votes boost gauges                                   │ streams MUSD
     │ harvest: incentives + rebase                                │ and stMEZO
     ▼                                                             │
 ┌─────────────────┐  BTC → MUSD on Mezo Pools                     │
 │ RewardHarvester │  MEZO → locked into the vault as stMEZO ──────┘
 └─────────────────┘  10% fee to the treasury (capped at 20%)
```

1. **Deposit.** `LocklessVault.deposit` adds MEZO to the master lock and mints the same amount of stMEZO. The first deposit creates the lock and makes it permanent.
2. **Convert a lock.** `LocklessVault.depositLock` takes a user's veMEZO NFT, clears its old votes and merges it into the master lock, minting stMEZO for the MEZO inside.
3. **Vote.** Each epoch the keeper reads every live boost gauge, values its incentives in USD and splits the lock's votes so every chosen gauge pays the same on its last vote (water-filling). Mezo allows 30 gauges per vote, so the plan keeps the best 30.
4. **Harvest.** After the epoch ends, the keeper claims the incentives and the veMEZO rebase. The harvester swaps BTC to MUSD, locks MEZO into the vault as stMEZO, keeps the protocol fee and streams the rest to stakers over seven days.

stMEZO supply always equals the MEZO in the master lock. Rebase growth is minted as stMEZO rewards, so the 1:1 backing holds.

## Contracts

| Contract | Job |
|---|---|
| [`LocklessVault`](contracts/src/LocklessVault.sol) | Owns the permanent master veMEZO lock. Deposits, lock conversion, voting, harvesting, rebases. |
| [`StMEZO`](contracts/src/StMEZO.sol) | The liquid receipt. ERC20 with permit. Only the vault can mint. |
| [`StMEZOStaking`](contracts/src/StMEZOStaking.sol) | Stake stMEZO, earn several reward tokens streamed over each epoch. |
| [`RewardHarvester`](contracts/src/RewardHarvester.sol) | Swaps incentives to MUSD, compounds MEZO into stMEZO, takes the fee, funds staking. |

### Testnet deployment (chain 31611)

Addresses are written to [`contracts/deployments/31611.json`](contracts/deployments) by the deploy script.

## Repository

```
contracts/   Foundry: contracts, unit tests, fork tests, deploy script
keeper/      TypeScript keeper: vote optimizer, harvest runner, CLI
app/         React + wagmi web app: deposit, convert a lock, stake
```

## Run the tests

```bash
# Contracts: unit tests against mocks that follow veMEZO's rules
cd contracts && forge test

# Contracts: the vault against the real Mezo testnet veMEZO and boost voter
RUN_FORK_TESTS=true forge test --match-path "test/fork/*"

# Keeper and app
cd keeper && pnpm install && pnpm test
cd app && pnpm install && pnpm test
```

The fork tests pin block 16,280,000 because one public RPC node lags the others. MEZO is a native precompile on Mezo that cannot run on a local fork, so the fork tests place a plain ERC20 at its address. Everything else is the real Mezo contracts.

## Deploy

```bash
cd contracts
# .env holds PRIVATE_KEY for a funded testnet wallet (gas is paid in BTC)
source .env
forge script script/DeployLockless.s.sol --rpc-url mezo_testnet --broadcast --private-key $PRIVATE_KEY
```

Optional settings: `KEEPER_ADDRESS`, `TREASURY_ADDRESS` and `FEE_BPS` (default 1000, which is 10%).

## Keeper

```bash
cd keeper
pnpm keeper status    # vault size, voting state, next epoch
pnpm keeper plan      # the best vote for this epoch, without sending it
pnpm keeper vote      # cast it, once per epoch, inside the voting window
pnpm keeper harvest   # claim incentives and rebase, convert, stream to stakers
pnpm keeper epoch     # harvest, then vote
```

It reads `contracts/deployments/31611.json` and `PRIVATE_KEY` from `contracts/.env`. Set `MEZO_USD_PRICE` to value MEZO incentives, because testnet has no MEZO pool to price it from.

## App

```bash
cd app && pnpm install && pnpm dev
```

Connect a browser wallet on Mezo testnet. Get test BTC and MEZO from the [faucet](https://faucet.test.mezo.org/).

## Known limits

- **stMEZO cannot be redeemed for MEZO.** The master lock is permanent, so holders leave by selling stMEZO, for example in a stMEZO/MEZO pool. Every liquid locker works this way. Yield and pool depth support the price.
- **Permanent locks need one extra step.** veMEZO forbids unlocking a permanent lock in the block it changes owner, so its owner turns off the permanent flag before converting. The app guides this.
- **A lock that voted this epoch waits until Thursday.** Its votes can only be reset in a new epoch.
- **Claim your lock's rewards before converting.** Rewards owed to a lock stay with that lock after it merges.
- **The keeper is trusted** to choose gauges. It cannot move user funds. Wave 2 adds on-chain limits on its votes.

## Roadmap (Wave 2)

- Real MUSD yield from live epochs.
- Borrow MUSD against stMEZO.
- A BTC side: the vault boosts its own veBTC positions with its votes, so BTC depositors get up to 5x boost without buying it.
- On-chain limits on keeper votes, then stMEZO-holder governance.
- stMEZO on Ethereum, Base and BNB Chain through Wormhole NTT, like MEZO.
