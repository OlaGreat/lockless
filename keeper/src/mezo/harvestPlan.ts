import type { Address } from "../allocation";
import { incentiveAbi } from "./abis";
import type { ContractReader } from "./reader";

export interface IncentiveSource {
  bribe: Address;
  rewardTokens: Address[];
}

export interface EarnedIncentive {
  bribe: Address;
  token: Address;
  amount: bigint;
}

export interface HarvestArguments {
  bribes: Address[];
  tokens: Address[][];
}

/** Checks every incentive contract for rewards the master lock can claim right now. */
export async function readEarnedIncentives(
  reader: ContractReader,
  masterTokenId: bigint,
  sources: IncentiveSource[],
): Promise<EarnedIncentive[]> {
  const pairs = sources.flatMap((source) =>
    source.rewardTokens.map((token) => ({ bribe: source.bribe, token })),
  );
  const amounts = await reader.readAll<bigint>(
    pairs.map((pair) => ({
      address: pair.bribe,
      abi: incentiveAbi,
      functionName: "earned",
      args: [pair.token, masterTokenId],
    })),
  );
  return pairs
    .map((pair, i) => ({ ...pair, amount: amounts[i] ?? 0n }))
    .filter((item) => item.amount > 0n);
}

/** Groups earned incentives into the arrays `LocklessVault.harvest` expects. */
export function toHarvestArguments(earned: EarnedIncentive[]): HarvestArguments {
  const tokensByBribe = new Map<Address, Address[]>();
  for (const item of earned) {
    const tokens = tokensByBribe.get(item.bribe) ?? [];
    tokens.push(item.token);
    tokensByBribe.set(item.bribe, tokens);
  }
  return { bribes: [...tokensByBribe.keys()], tokens: [...tokensByBribe.values()] };
}
