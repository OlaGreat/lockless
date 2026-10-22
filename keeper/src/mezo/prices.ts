import { formatEther } from "viem";
import type { Address } from "../allocation";
import { createPriceBook, type PriceBook } from "../valuation";
import { priceFeedAbi } from "./abis";
import type { ContractReader } from "./reader";

export interface PricedTokens {
  musd: Address;
  mezo: Address;
  btc: Address;
  btcPriceFeed: Address;
}

const MUSD_USD_PRICE = 1;
const DECIMALS = 18;

/** Prices the tokens incentives are paid in: MUSD at $1, BTC from Mezo's feed, MEZO as set. */
export async function readPriceBook(
  reader: ContractReader,
  tokens: PricedTokens,
  mezoUsdPrice: number,
): Promise<PriceBook> {
  const btcUsdPrice = await readBtcUsdPrice(reader, tokens.btcPriceFeed);
  return createPriceBook([
    { token: tokens.musd, usd: MUSD_USD_PRICE, decimals: DECIMALS },
    { token: tokens.btc, usd: btcUsdPrice, decimals: DECIMALS },
    { token: tokens.mezo, usd: mezoUsdPrice, decimals: DECIMALS },
  ]);
}

async function readBtcUsdPrice(reader: ContractReader, priceFeed: Address): Promise<number> {
  const [price] = await reader.readAll<bigint>([
    { address: priceFeed, abi: priceFeedAbi, functionName: "fetchPrice" },
  ]);
  return Number(formatEther(price ?? 0n));
}
