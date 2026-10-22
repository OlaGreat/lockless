import { parseUnits } from "viem";

const AMOUNT_PATTERN = /^\d+(\.\d+)?$/;

/** Reads a typed token amount, or null when it is not a positive decimal number. */
export function parseAmount(text: string, decimals = 18): bigint | null {
  const trimmed = text.trim();
  if (!AMOUNT_PATTERN.test(trimmed)) return null;
  return parseUnits(trimmed, decimals);
}

/** A message explaining why an amount cannot be used, or null when it is fine. */
export function amountError(text: string, balance: bigint, decimals = 18): string | null {
  const amount = parseAmount(text, decimals);
  if (amount === null) return "Enter a number";
  if (amount === 0n) return "Enter an amount above zero";
  if (amount > balance) return "That is more than your balance";
  return null;
}
