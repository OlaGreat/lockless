import type { Address } from "viem";
import { useReadContracts } from "wagmi";
import { erc20Abi } from "../config/abis";

const ZERO = "0x0000000000000000000000000000000000000000";

/** A wallet's balance of a token and how much a spender may move. */
export function useTokenAccount(token: Address, owner: Address | undefined, spender: Address) {
  const { data } = useReadContracts({
    contracts: [
      { address: token, abi: erc20Abi, functionName: "balanceOf", args: [owner ?? ZERO] },
      { address: token, abi: erc20Abi, functionName: "allowance", args: [owner ?? ZERO, spender] },
    ],
    query: { enabled: Boolean(owner) },
  });
  return { balance: data?.[0]?.result ?? 0n, allowance: data?.[1]?.result ?? 0n };
}
