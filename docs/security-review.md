# Security review

Lockless runs on Mezo testnet and has not had an external audit. This page lists every known issue, where it came from and what was done about it. It is updated with each fix.

Severity: **High** means funds can be taken. **Medium** means funds can be lost or stuck under realistic conditions. **Low** means a function can stop working or a smaller loss is possible. **Info** means behavior worth knowing.

## Findings

| ID | Severity | Finding | Reported by | Status |
|---|---|---|---|---|
| H-01 | High | The owner can point the vault's rewards receiver at any address at any time and take every incentive and rebase, bypassing the 20% fee cap. | Wave 1 judge review | Fixed in [9747e89] |
| M-01 | Medium | Converting a lock loses the incentives and rebase it has not claimed yet. Merging burns the lock, and Mezo only pays a lock's current owner. | KupiaSec | Fixed in [4b0eee4] and [9d4e011] |
| M-02 | Medium | The keeper sets the minimum MUSD for harvest swaps, so a malicious or compromised keeper can sandwich its own swaps and drain harvested BTC. | Internal review | Fixed in [1b6b48a] |
| M-03 | Medium | Rewards streamed while nobody is staked are lost: they stay in the staking contract with no way to pay them out. | KupiaSec | Fixed in [11ad2eb] |
| L-01 | Low | Rebase distribution reverts if veMEZO ever reports less MEZO in the master lock than the stMEZO supply. | KupiaSec | Fixed in [804e003] |
| L-02 | Low | The README and the app say a converted lock's rewards stay with that lock. They are lost (see M-01). | KupiaSec | Fixed in [064b7a1] and [fb7d112] |
| I-01 | Info | A lock that has votes cannot be converted in the first hour of an epoch, because Mezo blocks vote resets then. | Internal review | By design (Mezo rule) |
| I-02 | Info | Converting a lock with a pending rebase reverts until Mezo starts the new week's rebase period. | Internal review | By design: waiting is safer than losing the rebase |
| I-03 | Info | Converting pays out incentives only from the gauges the lock votes for now. Mezo keeps no on-chain list of older ones. | Internal review | Documented in the app and README |
| I-04 | Info | Converting calls every incentive token on the lock's gauges, so one token that reverts on `balanceOf` or `transfer` blocks conversion of locks voting that gauge. | Slither (calls-loop) | Accepted: Mezo governance whitelists incentive tokens |
| I-05 | Info | Mezo does not let unvested grant locks be merged, so they cannot be converted. | Internal review | By design (Mezo rule) |
| I-06 | Info | Converting a lock that votes for Mezo's maximum of 30 gauges cost 7.4M gas of the 10M block gas limit, because each gauge was claimed separately. | Fork test | Reduced to 5.7M in [723e1f1]; a fork test keeps it under 7.5M |

## Trust assumptions

These are known and disclosed rather than fixed.

- **The keeper chooses where the master lock votes.** It cannot move user funds, redirect rewards or sell BTC below 97% of the oracle price, but it could vote for gauges that pay little, or that benefit itself. On-chain limits on keeper votes are planned.
- **The owner is a single testnet wallet.** It can change the keeper and set the protocol fee up to the 20% cap without delay. It cannot redirect rewards. Before mainnet, ownership moves to a multisig behind a timelock.
- **stMEZO cannot be redeemed for MEZO.** The master lock is permanent, so holders exit by selling stMEZO.
- **Mezo's contracts are upgradeable.** veMEZO, the boost voter and the price feed sit behind proxies Mezo controls. The fixes were checked against the implementations deployed on 2026-11-02.

## Details

### H-01: Owner could redirect all rewards

`LocklessVault.setRewardsReceiver` could be called by the owner at any time. Harvested incentives and rebase stMEZO go to the receiver, so pointing it at the owner's own address would take everything stakers earn.

**Fix.** The receiver can be set only once. The deploy script sets it to the harvester in the same run that deploys the vault.

### M-01: Converting a lock lost its unclaimed rewards

`depositLock` reset the incoming lock's votes and merged it into the master lock. Merging burns the incoming lock. Mezo's incentive contracts pay `ownerOf(tokenId)` and only accept claims from the owner, an approved address or the voter (tigris `VotingReward.getReward`), so after the burn nobody could claim what the lock earned. The same applied to its pending rebase.

**Fix.** While the vault owns the lock, and before resetting its votes (a reset deletes the voter's record of its gauges), `depositLock` reads each gauge the lock votes for, claims that gauge's incentives and sends what arrived to the receiver. It then claims the lock's rebase: Mezo adds it to a live lock, which the vault then mints stMEZO for, and pays an expired lock's rebase out as MEZO, which the vault locks into the master lock and mints stMEZO for. A fork test adds a real incentive on a live Mezo gauge and fails on the old code.

### M-02: Keeper controlled swap slippage

`RewardHarvester.swapToMusd` accepted any `minMusdOut` from the keeper. A keeper could set it to zero, move the pool price with its own funds, swap the harvest at the bad price and move the price back.

**Fix.** `swapBtcToMusd` checks the MUSD actually received and reverts if it is below 97% of the BTC's value at Mezo's oracle price. Mezo's price feed reverts when its price is more than 60 seconds old, which also stops the swap. Only BTC can be swapped, because it is the only incentive token with an on-chain price. MEZO is locked as stMEZO and MUSD is streamed as it is. The keeper skips the swap when the pool quotes below the floor.

### M-03: Rewards were lost while nobody was staked

`StMEZOStaking` kept the reward stream running while the total stake was zero. That time's share of rewards was assigned to nobody and could never be claimed.

**Fix.** When the stake is zero, the stream's end moves back by the time that passed, so the rewards are streamed to the next stakers instead.

### L-01: Rebase distribution could underflow

`_unbackedMezo` returned `lockedAmount() - stMEZO.totalSupply()`. If veMEZO, which Mezo can upgrade, ever reported less, the subtraction would revert and block `claimRebase` and `distributeRebase`.

**Fix.** It returns zero when the lock reports no more than the supply.

### L-02: Docs described lost rewards as safe

The README and the convert screen told users rewards stay with a converted lock.

**Fix.** Both now describe what converting pays out, and a test checks the convert screen's wording.

## How the fixes were checked

- **Unit tests** for every fix, written before the fix and failing first. The test doubles for veMEZO, the boost voter, the incentive contracts, the rebase distributor and the price feed follow the deployed Mezo source, including who gets paid and the error names.
- **Fork tests** against the real Mezo testnet contracts:
  - converting a lock with a real pending incentive, and keeping the master lock's own incentives in place
  - converting a lock with a real pending rebase, produced by running Mezo's own weekly update
  - converting a lock that voted for 30 live gauges with two incentive tokens each, within a gas bound
  - the keeper's harvest of real incentives and the master lock's real rebase claim
  - pricing swaps with the real price feed
  The fork stands in for the MEZO, BTC and oracle precompiles, which cannot run off-chain, with values recorded from the live chain. The new conversion tests fail on the code before the fix.
- **Deployment** simulated against the live testnet: every transaction fits the block gas limit (the largest is 4.4M) and every contract is under the 24 KB size limit.
- **Invariant tests** on staking: under random stakes, withdrawals, claims, top-ups and time jumps, the contract never owes more than it holds, never pays out more than it received, and holds every staked token.
- **Slither 0.11.6**: 37 results, all triaged. None needed a code change. They are external calls in loops (I-04), timestamp use for epochs, zero checks done through a helper Slither does not follow, strict equality on zero balances that only skip empty transfers, ignored return values where the code measures balances instead, and one cache-array-length gas note.

## Not yet verified on the live chain

Mezo's MEZO and BTC tokens and its price oracle are precompiles that only run on Mezo itself, so these steps can only be confirmed after deploying:

- A BTC to MUSD swap through the harvester on the real Mezo Pools router.
- The keeper's full harvest run against the new contracts.
- A conversion of a lock that earned BTC incentives.

Each is run on testnet right after deploying, and this section is updated with the transactions.

## Credits

Thanks to KupiaSec for reporting M-01, M-03 and L-01, and to the Mezo Buildathon Wave 1 judges for H-01.

[9747e89]: https://github.com/OlaGreat/lockless/commit/9747e89
[804e003]: https://github.com/OlaGreat/lockless/commit/804e003
[4b0eee4]: https://github.com/OlaGreat/lockless/commit/4b0eee4
[9d4e011]: https://github.com/OlaGreat/lockless/commit/9d4e011
[1b6b48a]: https://github.com/OlaGreat/lockless/commit/1b6b48a
[11ad2eb]: https://github.com/OlaGreat/lockless/commit/11ad2eb
[064b7a1]: https://github.com/OlaGreat/lockless/commit/064b7a1
[fb7d112]: https://github.com/OlaGreat/lockless/commit/fb7d112
[723e1f1]: https://github.com/OlaGreat/lockless/commit/723e1f1
