import type { Abi, PublicClient } from "viem";
import type { Address } from "../allocation";

export interface ContractCall {
  address: Address;
  abi: Abi;
  functionName: string;
  args?: readonly unknown[];
}

/** Reads many contract values at once. Lets chain logic run against a fake in tests. */
export interface ContractReader {
  readAll<T>(calls: ContractCall[]): Promise<T[]>;
}

/** Keeps each Multicall3 request small enough for the public Mezo RPC. */
const MULTICALL_BATCH_SIZE = 250;

type MulticallContracts = Parameters<PublicClient["multicall"]>[0]["contracts"];

export function multicallReader(client: PublicClient): ContractReader {
  return {
    async readAll<T>(calls: ContractCall[]): Promise<T[]> {
      const results: T[] = [];
      for (const batch of chunk(calls, MULTICALL_BATCH_SIZE)) {
        const contracts = batch as unknown as MulticallContracts;
        const values = await client.multicall({ contracts, allowFailure: false });
        results.push(...(values as T[]));
      }
      return results;
    },
  };
}

function chunk<T>(items: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let start = 0; start < items.length; start += size) {
    chunks.push(items.slice(start, start + size));
  }
  return chunks;
}
