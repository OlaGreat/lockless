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

/** Sends a transaction, waits for it and returns its explorer link. */
export async function sendAndWait(
  reader: PublicClient,
  signer: WalletClient,
  call: WriteCall,
): Promise<string> {
  const hash = await signer.writeContract({
    ...call,
    account: signer.account!,
    chain: signer.chain,
  } as Parameters<WalletClient["writeContract"]>[0]);
  const receipt = await reader.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") throw new Error(`Transaction failed: ${EXPLORER_URL}/tx/${hash}`);
  return `${EXPLORER_URL}/tx/${hash}`;
}
