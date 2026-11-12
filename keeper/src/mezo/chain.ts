import {
  createPublicClient,
  createWalletClient,
  defineChain,
  http,
  type Abi,
  type PublicClient,
  type WalletClient,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import type { Address } from "../allocation";
import type { KeeperConfig } from "../config";

const MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11";
const RPC_RETRIES = 5;
/** Calls into other contracts can need more gas than the node estimates. */
const GAS_HEADROOM_PERCENT = 30n;
/** One testnet node lags behind, so a receipt can take a while to show. */
const RECEIPT_RETRIES = 30;
export const EXPLORER_URL = "https://explorer.test.mezo.org";

export function mezoTestnet(rpcUrl: string) {
  return defineChain({
    id: 31611,
    name: "Mezo Testnet",
    nativeCurrency: { name: "Bitcoin", symbol: "BTC", decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
    blockExplorers: { default: { name: "Mezo Explorer", url: EXPLORER_URL } },
    contracts: { multicall3: { address: MULTICALL3 } },
  });
}

export function createReadClient(config: KeeperConfig): PublicClient {
  return createPublicClient({
    chain: mezoTestnet(config.rpcUrl),
    transport: http(config.rpcUrl, { retryCount: RPC_RETRIES }),
  });
}

export function createSigningClient(config: KeeperConfig): WalletClient {
  if (!config.privateKey) throw new Error("Set PRIVATE_KEY to send transactions");
  return createWalletClient({
    account: privateKeyToAccount(config.privateKey),
    chain: mezoTestnet(config.rpcUrl),
    transport: http(config.rpcUrl, { retryCount: RPC_RETRIES }),
  });
}

export interface WriteCall {
  address: Address;
  abi: Abi;
  functionName: string;
  args?: readonly unknown[];
}

/** Adds headroom to a gas estimate so the transaction does not run out of gas. */
export function gasWithHeadroom(estimate: bigint): bigint {
  return (estimate * (100n + GAS_HEADROOM_PERCENT)) / 100n;
}

/** Sends a transaction, waits for it and returns its explorer link. */
export async function sendAndWait(
  reader: PublicClient,
  signer: WalletClient,
  call: WriteCall,
): Promise<string> {
  const request = { ...call, account: signer.account!, chain: signer.chain };
  const estimate = await reader.estimateContractGas(request as Parameters<PublicClient["estimateContractGas"]>[0]);
  const hash = await signer.writeContract({
    ...request,
    gas: gasWithHeadroom(estimate),
  } as Parameters<WalletClient["writeContract"]>[0]);
  const receipt = await reader.waitForTransactionReceipt({ hash, retryCount: RECEIPT_RETRIES });
  if (receipt.status !== "success") throw new Error(`Transaction failed: ${EXPLORER_URL}/tx/${hash}`);
  return `${EXPLORER_URL}/tx/${hash}`;
}
