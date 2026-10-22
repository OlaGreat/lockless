import { isAddress, isHex } from "viem";
import type { Address } from "./allocation";

export const DEFAULT_RPC_URL = "https://rpc.test.mezo.org";

const DEPLOYED_CONTRACTS = [
  "vault",
  "stMEZO",
  "staking",
  "harvester",
  "veMEZO",
  "boostVoter",
  "rebaseDistributor",
  "router",
  "musd",
  "mezo",
] as const;

type DeployedContract = (typeof DEPLOYED_CONTRACTS)[number];

/** Mezo contracts the keeper needs that are not part of the Lockless deployment. */
const CHAIN_CONTRACTS: Record<number, { btc: Address; btcPriceFeed: Address }> = {
  31611: {
    btc: "0x7b7C000000000000000000000000000000000000",
    btcPriceFeed: "0x86bCF0841622a5dAC14A313a15f96A95421b9366",
  },
};

export type KeeperContracts = Record<DeployedContract, Address> & {
  btc: Address;
  btcPriceFeed: Address;
};

export interface KeeperConfig {
  chainId: number;
  rpcUrl: string;
  privateKey?: `0x${string}`;
  mezoUsdPrice: number;
  contracts: KeeperContracts;
}

type Env = Record<string, string | undefined>;

/** Builds keeper settings from the deployment file and environment variables. */
export function parseConfig(deployment: Record<string, unknown>, env: Env): KeeperConfig {
  const chainId = Number(deployment.chainId);
  return {
    chainId,
    rpcUrl: env.MEZO_RPC_URL ?? DEFAULT_RPC_URL,
    privateKey: parsePrivateKey(env.PRIVATE_KEY),
    mezoUsdPrice: Number(env.MEZO_USD_PRICE ?? 0),
    contracts: { ...readDeployedContracts(deployment), ...chainContracts(chainId) },
  };
}

function readDeployedContracts(deployment: Record<string, unknown>): Record<DeployedContract, Address> {
  const entries = DEPLOYED_CONTRACTS.map((name) => [name, requireAddress(deployment, name)]);
  return Object.fromEntries(entries) as Record<DeployedContract, Address>;
}

function requireAddress(deployment: Record<string, unknown>, name: string): Address {
  const value = deployment[name];
  if (typeof value !== "string" || !isAddress(value)) {
    throw new Error(`Deployment file has no valid address for "${name}"`);
  }
  return value;
}

function chainContracts(chainId: number): { btc: Address; btcPriceFeed: Address } {
  const contracts = CHAIN_CONTRACTS[chainId];
  if (!contracts) throw new Error(`No keeper settings for chain ${chainId}`);
  return contracts;
}

function parsePrivateKey(value: string | undefined): `0x${string}` | undefined {
  if (value === undefined) return undefined;
  if (!isHex(value) || value.length !== 66) throw new Error("PRIVATE_KEY must be 32 bytes of hex");
  return value;
}
