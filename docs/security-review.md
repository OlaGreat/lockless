# Security review

Lockless runs on Mezo testnet and has not had an external audit. This page lists every known issue, where it came from and what was done about it. It is updated with each fix.

Severity: **High** means funds can be taken. **Medium** means funds can be lost or stuck under realistic conditions. **Low** means a function can stop working or a smaller loss is possible. **Info** means behavior worth knowing.

## Findings

| ID | Severity | Finding | Reported by | Status |
|---|---|---|---|---|
| H-01 | High | The owner can point the vault's rewards receiver at any address at any time and take every incentive and rebase, bypassing the 20% fee cap. | Wave 1 judge review | Open |
| M-01 | Medium | Converting a lock loses the incentives and rebase it has not claimed yet. Merging burns the lock, and Mezo only pays a lock's current owner. | KupiaSec | Open |
| M-02 | Medium | The keeper sets the minimum MUSD for harvest swaps, so a malicious or compromised keeper can sandwich its own swaps and drain harvested BTC. | Internal review | Open |
| M-03 | Medium | Rewards streamed while nobody is staked are lost: they stay in the staking contract with no way to pay them out. | KupiaSec | Open |
| L-01 | Low | Rebase distribution reverts if veMEZO ever reports less MEZO in the master lock than the stMEZO supply. | KupiaSec | Open |
| L-02 | Low | The README and the app say a converted lock's rewards stay with that lock. They are lost (see M-01). | KupiaSec | Open |

## Trust assumptions

These are known and disclosed rather than fixed.

- **The keeper chooses where the master lock votes.** It cannot move user funds, but it could vote for gauges that pay little, or that benefit itself. On-chain limits on keeper votes are planned.
- **The owner is a single testnet wallet.** It can change the keeper and set the protocol fee up to the 20% cap without delay. Before mainnet, ownership moves to a multisig behind a timelock.
- **stMEZO cannot be redeemed for MEZO.** The master lock is permanent, so holders exit by selling stMEZO.

## Details

### H-01: Owner can redirect all rewards

`LocklessVault.setRewardsReceiver` could be called by the owner at any time. Harvested incentives and rebase stMEZO go to the receiver, so pointing it at the owner's own address would take everything stakers earn.

### M-01: Converting a lock loses its unclaimed rewards

`depositLock` reset the incoming lock's votes and merged it into the master lock. Merging burns the incoming lock. Mezo's incentive contracts pay `ownerOf(tokenId)` and only accept claims from the owner, an approved address or the voter, so after the burn nobody can claim what the lock earned. The same applies to its pending rebase.

### M-02: Keeper controls swap slippage

`RewardHarvester.swapToMusd` accepted any `minMusdOut` from the keeper. A keeper could set it to zero, move the pool price with its own funds, swap the harvest at the bad price and move the price back.

### M-03: Rewards lost while nobody is staked

`StMEZOStaking` kept the reward stream running while the total stake was zero. That time's share of rewards was assigned to nobody and could never be claimed.

### L-01: Rebase distribution can underflow

`_unbackedMezo` returned `lockedAmount() - stMEZO.totalSupply()`. If veMEZO, which Mezo can upgrade, ever reported less, the subtraction would revert and block `claimRebase` and `distributeRebase`.

### L-02: Docs described lost rewards as safe

The README and the convert screen told users rewards stay with a converted lock. They do not.

## Credits

Thanks to KupiaSec for reporting M-01, M-03 and L-01, and to the Mezo Buildathon Wave 1 judges for H-01.
