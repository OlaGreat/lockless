import type { Address } from "viem";
import { boostVoterAbi, vaultAbi, veMezoAbi } from "../config/abis";
import type { Deployment } from "../config/deployment";
import type { LockAction } from "./lockAction";

type LockContracts = Pick<Deployment, "vault" | "veMEZO" | "boostVoter">;

/** The transaction that performs a lock step, or null when the user cannot act yet. */
export function lockRequest(
  action: LockAction,
  tokenId: bigint,
  contracts: LockContracts,
  account: Address,
) {
  switch (action) {
    case "convert":
      return { address: contracts.vault, abi: vaultAbi, functionName: "depositLock", args: [tokenId, account] } as const;
    case "approve":
      return { address: contracts.veMEZO, abi: veMezoAbi, functionName: "approve", args: [contracts.vault, tokenId] } as const;
    case "unlock-permanent":
      return { address: contracts.veMEZO, abi: veMezoAbi, functionName: "unlockPermanent", args: [tokenId] } as const;
    case "reset-votes":
      return { address: contracts.boostVoter, abi: boostVoterAbi, functionName: "reset", args: [tokenId] } as const;
    default:
      return null;
  }
}
