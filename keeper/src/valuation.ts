import { formatUnits } from "viem";
import type { Address } from "./allocation";

export interface TokenAmount {
  token: Address;
  amount: bigint;
}

export interface TokenPrice {
  token: Address;
  usd: number;
  decimals: number;
}

/** Token prices keyed by lowercase address. */
export type PriceBook = ReadonlyMap<string, TokenPrice>;

export function createPriceBook(prices: TokenPrice[]): PriceBook {
  return new Map(prices.map((price) => [price.token.toLowerCase(), price]));
}

/** USD value of a set of token amounts. Tokens without a price count as zero. */
export function valueInUsd(amounts: TokenAmount[], prices: PriceBook): number {
  return amounts.reduce((sum, item) => sum + valueOf(item, prices), 0);
}

function valueOf(item: TokenAmount, prices: PriceBook): number {
  const price = prices.get(item.token.toLowerCase());
  if (!price) return 0;
  return Number(formatUnits(item.amount, price.decimals)) * price.usd;
}
