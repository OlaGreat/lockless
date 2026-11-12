import type { WalletClient } from "viem";
import {
  btcSwapMinimum,
  planConversions,
  planDistributions,
  planRebase,
  type Conversion,
  type Distribution,
  type HarvesterBalances,
} from "../decisions";
import { erc20Abi, harvesterAbi, rebaseDistributorAbi, routerAbi, vaultAbi } from "../mezo/abis";
import { sendAndWait, type WriteCall } from "../mezo/chain";
import { readEarnedIncentives, toHarvestArguments } from "../mezo/harvestPlan";
import { readOpportunities } from "../mezo/opportunities";
import { createPriceBook } from "../valuation";
import type { KeeperContext } from "./context";
import { readMasterTokenId } from "./plan";

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

/** Claims or mints the rebase only when there is some. A failure is reported and skipped. */
async function claimRebase(ctx: KeeperContext, signer: WalletClient): Promise<void> {
  const step = planRebase(await readRebaseState(ctx));
  if (!step) {
    ctx.log("No rebase to claim.");
    return;
  }
  try {
    const label = step === "claimRebase" ? "Claimed rebase" : "Minted stMEZO for the rebase";
    await send(ctx, signer, label, vaultCall(ctx, step));
  } catch (error) {
    ctx.log(`Rebase not claimed: ${(error as Error).message.split("\n")[0]}`);
  }
}

async function readRebaseState(ctx: KeeperContext) {
  const { contracts } = ctx.config;
  const masterTokenId = await readMasterTokenId(ctx);
  const [claimable, lockedMezo, stMezoSupply] = await ctx.reader.readAll<bigint>([
    { address: contracts.rebaseDistributor, abi: rebaseDistributorAbi, functionName: "claimable", args: [masterTokenId] },
    { address: contracts.vault, abi: vaultAbi, functionName: "lockedAmount" },
    { address: contracts.stMEZO, abi: erc20Abi, functionName: "totalSupply" },
  ]);
  return { claimable: claimable ?? 0n, lockedMezo: lockedMezo ?? 0n, stMezoSupply: stMezoSupply ?? 0n };
}

/** Converts first, then streams what the harvester actually holds, since a swap may be skipped. */
async function processRewards(ctx: KeeperContext, signer: WalletClient): Promise<void> {
  for (const step of planConversions(await readHarvesterBalances(ctx))) {
    await runConversion(ctx, signer, step);
  }
  const distributions = planDistributions(await readHarvesterBalances(ctx));
  if (distributions.length === 0) ctx.log("Nothing for the harvester to distribute.");
  for (const step of distributions) await runDistribution(ctx, signer, step);
}

async function runConversion(ctx: KeeperContext, signer: WalletClient, step: Conversion): Promise<void> {
  if (step === "lockMezo") await send(ctx, signer, "Locked MEZO incentives", harvesterCall(ctx, "lockMezo"));
  if (step === "swapBtcToMusd") await swapBtcToMusd(ctx, signer);
}

async function runDistribution(ctx: KeeperContext, signer: WalletClient, step: Distribution): Promise<void> {
  const { contracts } = ctx.config;
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
  const [oracleFloor] = await ctx.reader.readAll<bigint>([
    { address: contracts.harvester, abi: harvesterAbi, functionName: "oracleFloor", args: [amountIn] },
  ]);
  const decision = btcSwapMinimum(amounts?.at(-1) ?? 0n, oracleFloor ?? 0n);
  if (!decision.swap) {
    ctx.log(`BTC not swapped: ${decision.reason}.`);
    return;
  }
  const args = [amountIn, decision.minOut, routes];
  await send(ctx, signer, "Swapped BTC incentives to MUSD", harvesterCall(ctx, "swapBtcToMusd", args));
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
