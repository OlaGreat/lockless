import type { Address } from "viem";

/** Accepts at most 1% less MEZO than the pool quotes. */
export const SELL_SLIPPAGE_BPS = 100n;

const BPS = 10_000n;
const DEADLINE_SECONDS = 20 * 60;

export interface Route {
  from: Address;
  to: Address;
  stable: boolean;
  factory: Address;
}

/** The least MEZO the swap may return before it reverts. */
export function minimumReceived(quoted: bigint, slippageBps = SELL_SLIPPAGE_BPS): bigint {
  return (quoted * (BPS - slippageBps)) / BPS;
}

/** How the pool's price compares with one MEZO per stMEZO, such as "2.4% below 1:1". */
export function describePriceVsPar(stMezoIn: bigint, mezoOut: bigint): string {
  if (mezoOut === stMezoIn) return "at 1:1";
  const gap = mezoOut < stMezoIn ? stMezoIn - mezoOut : mezoOut - stMezoIn;
  const percent = (Number((gap * BPS) / stMezoIn) / 100).toFixed(1);
  return `${percent}% ${mezoOut < stMezoIn ? "below" : "above"} 1:1`;
}

/** The Mezo Pools route for selling stMEZO. The stMEZO/MEZO pool is a volatile pool. */
export function sellRoute(stMEZO: Address, mezo: Address, factory: Address): Route[] {
  return [{ from: stMEZO, to: mezo, stable: false, factory }];
}

/** The latest time the swap may be mined, in seconds. */
export function swapDeadline(nowSeconds: number): bigint {
  return BigInt(nowSeconds + DEADLINE_SECONDS);
}
