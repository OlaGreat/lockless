import { formatUnits } from "viem";

const TWO_DECIMALS = new Intl.NumberFormat("en-US", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

/** A token amount with two decimals and thousands separators. */
export function formatToken(amount: bigint, decimals = 18): string {
  return TWO_DECIMALS.format(Number(formatUnits(amount, decimals)));
}

/** A duration like "2d 4h 10m", leaving out empty leading units. */
export function formatCountdown(seconds: number): string {
  const total = Math.max(0, Math.floor(seconds));
  const days = Math.floor(total / 86_400);
  const hours = Math.floor((total % 86_400) / 3_600);
  const minutes = Math.floor((total % 3_600) / 60);
  if (days > 0) return `${days}d ${hours}h ${minutes}m`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

export function shortAddress(address: string): string {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}
