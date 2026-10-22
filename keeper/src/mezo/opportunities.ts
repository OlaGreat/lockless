import { formatEther } from "viem";
import type { Address, GaugeOpportunity } from "../allocation";
import { valueInUsd, type PriceBook } from "../valuation";
import { boostVoterAbi, incentiveAbi } from "./abis";
import type { ContractCall, ContractReader } from "./reader";

/** A gauge the vault could vote for, with what is needed to harvest it later. */
export interface GaugeOpportunityWithRewards extends GaugeOpportunity {
  bribe: Address;
  rewardTokens: Address[];
}

export interface OpportunityQuery {
  voter: Address;
  masterTokenId: bigint;
  epochStart: bigint;
  prices: PriceBook;
}

interface GaugeDetails {
  gauge: Address;
  bribe: Address;
  weight: bigint;
  ourVotes: bigint;
}

/** Reads every live boost gauge with its incentives for the epoch and its other votes. */
export async function readOpportunities(
  reader: ContractReader,
  query: OpportunityQuery,
): Promise<GaugeOpportunityWithRewards[]> {
  const gauges = await readGauges(reader, query.voter);
  const liveGauges = await keepLiveGauges(reader, query.voter, gauges);
  const details = await readGaugeDetails(reader, query, liveGauges);
  const rewardTokens = await readRewardTokens(reader, details.map((detail) => detail.bribe));
  const amounts = await readEpochAmounts(reader, details, rewardTokens, query.epochStart);

  return details.map((detail, i) =>
    toOpportunity(detail, rewardTokens[i] ?? [], amounts[i] ?? [], query.prices),
  );
}

async function readGauges(reader: ContractReader, voter: Address): Promise<Address[]> {
  const [count] = await reader.readAll<bigint>([voterCall(voter, "length")]);
  const indexes = Array.from({ length: Number(count) }, (_, i) => BigInt(i));
  return reader.readAll<Address>(indexes.map((i) => voterCall(voter, "gauges", [i])));
}

async function keepLiveGauges(
  reader: ContractReader,
  voter: Address,
  gauges: Address[],
): Promise<Address[]> {
  const alive = await reader.readAll<boolean>(gauges.map((g) => voterCall(voter, "isAlive", [g])));
  return gauges.filter((_, i) => alive[i]);
}

async function readGaugeDetails(
  reader: ContractReader,
  query: OpportunityQuery,
  gauges: Address[],
): Promise<GaugeDetails[]> {
  const calls = gauges.flatMap((gauge) => [
    voterCall(query.voter, "gaugeToBribe", [gauge]),
    voterCall(query.voter, "weights", [gauge]),
    voterCall(query.voter, "votes", [query.masterTokenId, gauge]),
  ]);
  const values = await reader.readAll<Address | bigint>(calls);
  return gauges.map((gauge, i) => ({
    gauge,
    bribe: values[i * 3] as Address,
    weight: values[i * 3 + 1] as bigint,
    ourVotes: values[i * 3 + 2] as bigint,
  }));
}

async function readRewardTokens(reader: ContractReader, bribes: Address[]): Promise<Address[][]> {
  const counts = await reader.readAll<bigint>(
    bribes.map((bribe) => incentiveCall(bribe, "rewardsListLength")),
  );
  const calls = bribes.flatMap((bribe, i) =>
    Array.from({ length: Number(counts[i]) }, (_, j) => incentiveCall(bribe, "rewards", [BigInt(j)])),
  );
  const tokens = await reader.readAll<Address>(calls);
  return regroup(tokens, counts.map(Number));
}

async function readEpochAmounts(
  reader: ContractReader,
  details: GaugeDetails[],
  rewardTokens: Address[][],
  epochStart: bigint,
): Promise<bigint[][]> {
  const calls = details.flatMap((detail, i) =>
    (rewardTokens[i] ?? []).map((token) =>
      incentiveCall(detail.bribe, "tokenRewardsPerEpoch", [token, epochStart]),
    ),
  );
  const amounts = await reader.readAll<bigint>(calls);
  return regroup(amounts, rewardTokens.map((tokens) => tokens.length));
}

function toOpportunity(
  detail: GaugeDetails,
  tokens: Address[],
  amounts: bigint[],
  prices: PriceBook,
): GaugeOpportunityWithRewards {
  const incentives = tokens.map((token, i) => ({ token, amount: amounts[i] ?? 0n }));
  return {
    gauge: detail.gauge,
    bribe: detail.bribe,
    rewardTokens: tokens,
    incentiveUsd: valueInUsd(incentives, prices),
    otherVotes: Number(formatEther(detail.weight - detail.ourVotes)),
  };
}

function regroup<T>(flat: T[], sizes: number[]): T[][] {
  let offset = 0;
  return sizes.map((size) => {
    const group = flat.slice(offset, offset + size);
    offset += size;
    return group;
  });
}

function voterCall(voter: Address, functionName: string, args: readonly unknown[] = []): ContractCall {
  return { address: voter, abi: boostVoterAbi, functionName, args };
}

function incentiveCall(
  bribe: Address,
  functionName: string,
  args: readonly unknown[] = [],
): ContractCall {
  return { address: bribe, abi: incentiveAbi, functionName, args };
}
