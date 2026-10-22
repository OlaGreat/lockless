import type { WalletClient } from "viem";
import { planRewardSteps, type HarvesterBalances, type RewardStep } from "../decisions";
import { erc20Abi, harvesterAbi, routerAbi, vaultAbi } from "../mezo/abis";
import { sendAndWait, type WriteCall } from "../mezo/chain";
import { readEarnedIncentives, toHarvestArguments } from "../mezo/harvestPlan";
import { readOpportunities } from "../mezo/opportunities";
import { createPriceBook } from "../valuation";
import type { KeeperContext } from "./context";
import { readMasterTokenId } from "./plan";

/** Accepts at most 1% less MUSD than the router quotes when swapping BTC incentives. */
const SLIPPAGE_BPS = 100n;

/** Claims incentives and the rebase, converts rewards and streams them to stakers. */
export async function runHarvest(ctx: KeeperContext, signer: WalletClient): Promise<void> {
  await claimIncentives(ctx, signer);
  await claimRebase(ctx, signer);
  await processRewards(ctx, signer);
}

async function claimIncentives(ctx: KeeperContext, signer: WalletClient): Promise<void> {
  const masterTokenId = await readMasterTokenId(ctx);
  const sources = await readOpportunities(ctx.reader, {
    voter: ctx.config.contracts.boostVoter,
    masterTokenId,
    epochStart: 0n,
    prices: createPriceBook([]),
  });
  const earned = await readEarnedIncentives(ctx.reader, masterTokenId, sources);
  if (earned.length === 0) {
    ctx.log("No incentives to claim.");
    return;
  }
  const { bribes, tokens } = toHarvestArguments(earned);
  await send(ctx, signer, "Harvested incentives", vaultCall(ctx, "harvest", [bribes, tokens]));
}

/** The rebase can only be claimed once per epoch, so a failed claim is reported and skipped. */
async function claimRebase(ctx: KeeperContext, signer: WalletClient): Promise<void> {
  try {
    await send(ctx, signer, "Claimed rebase", vaultCall(ctx, "claimRebase"));
  } catch (error) {
    ctx.log(`Rebase not claimed: ${(error as Error).message.split("\n")[0]}`);
  }
}

async function processRewards(ctx: KeeperContext, signer: WalletClient): Promise<void> {
  const steps = planRewardSteps(await readHarvesterBalances(ctx));
  if (steps.length === 0) ctx.log("Nothing for the harvester to distribute.");
  for (const step of steps) await runRewardStep(ctx, signer, step);
}

async function runRewardStep(ctx: KeeperContext, signer: WalletClient, step: RewardStep): Promise<void> {
  const { contracts } = ctx.config;
  if (step === "lockMezo") await send(ctx, signer, "Locked MEZO incentives", harvesterCall(ctx, "lockMezo"));
  if (step === "swapBtcToMusd") await swapBtcToMusd(ctx, signer);
  if (step === "distributeMusd") {
    await send(ctx, signer, "Streamed MUSD to stakers", harvesterCall(ctx, "distribute", [contracts.musd]));
  }
  if (step === "distributeStMEZO") {
    await send(ctx, signer, "Streamed stMEZO to stakers", harvesterCall(ctx, "distribute", [contracts.stMEZO]));
  }
}

async function swapBtcToMusd(ctx: KeeperContext, signer: WalletClient): Promise<void> {
  const { contracts } = ctx.config;
  const [amountIn] = await readBalances(ctx, [contracts.btc]);
  const [factory] = await ctx.reader.readAll<`0x${string}`>([
    { address: contracts.router, abi: routerAbi, functionName: "defaultFactory" },
  ]);
  const routes = [{ from: contracts.btc, to: contracts.musd, stable: false, factory: factory! }];
  const [amounts] = await ctx.reader.readAll<bigint[]>([
    { address: contracts.router, abi: routerAbi, functionName: "getAmountsOut", args: [amountIn, routes] },
  ]);
  const quoted = amounts?.at(-1) ?? 0n;
  const minOut = (quoted * (10_000n - SLIPPAGE_BPS)) / 10_000n;
  await send(ctx, signer, "Swapped BTC incentives to MUSD", harvesterCall(ctx, "swapToMusd", [contracts.btc, amountIn, minOut, routes]));
}

async function readHarvesterBalances(ctx: KeeperContext): Promise<HarvesterBalances> {
  const { contracts } = ctx.config;
  const [mezo, btc, musd, stMEZO] = await readBalances(ctx, [
    contracts.mezo,
    contracts.btc,
    contracts.musd,
    contracts.stMEZO,
  ]);
  return { mezo: mezo ?? 0n, btc: btc ?? 0n, musd: musd ?? 0n, stMEZO: stMEZO ?? 0n };
}

function readBalances(ctx: KeeperContext, tokens: `0x${string}`[]): Promise<bigint[]> {
  return ctx.reader.readAll<bigint>(
    tokens.map((token) => ({
      address: token,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [ctx.config.contracts.harvester],
    })),
  );
}

function vaultCall(ctx: KeeperContext, functionName: string, args: readonly unknown[] = []): WriteCall {
  return { address: ctx.config.contracts.vault, abi: vaultAbi, functionName, args };
}

function harvesterCall(ctx: KeeperContext, functionName: string, args: readonly unknown[] = []): WriteCall {
  return { address: ctx.config.contracts.harvester, abi: harvesterAbi, functionName, args };
}

async function send(ctx: KeeperContext, signer: WalletClient, label: string, call: WriteCall): Promise<void> {
  ctx.log(`${label}: ${await sendAndWait(ctx.client, signer, call)}`);
}
