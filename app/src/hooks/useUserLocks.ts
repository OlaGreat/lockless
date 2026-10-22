import type { Address } from "viem";
import { useReadContract, useReadContracts } from "wagmi";
import { boostVoterAbi, veMezoAbi } from "../config/abis";
import type { Deployment } from "../config/deployment";
import type { LockInfo } from "../lib/lockAction";
import { toLockInfo, type LockReads } from "../lib/lockView";

const READS_PER_LOCK = 6;

/** Every veMEZO lock a wallet owns, with what is needed to convert it. */
export function useUserLocks(deployment: Deployment, owner: Address | undefined): LockInfo[] {
  const tokenIds = useOwnedTokenIds(deployment, owner);
  const { data } = useReadContracts({
    contracts: tokenIds.flatMap((tokenId) => lockReads(deployment, tokenId)),
    query: { enabled: tokenIds.length > 0 },
  });
  if (!data) return [];
  return tokenIds.map((tokenId, i) => {
    const values = data.slice(i * READS_PER_LOCK, (i + 1) * READS_PER_LOCK).map((r) => r.result);
    return toLockInfo(tokenId, toReads(values), deployment.vault);
  });
}

function useOwnedTokenIds(deployment: Deployment, owner: Address | undefined): bigint[] {
  const { data: count } = useReadContract({
    address: deployment.veMEZO,
    abi: veMezoAbi,
    functionName: "balanceOf",
    args: owner ? [owner] : undefined,
    query: { enabled: Boolean(owner) },
  });
  const indexes = Array.from({ length: Number(count ?? 0n) }, (_, i) => BigInt(i));
  const { data } = useReadContracts({
    contracts: indexes.map((index) => ({
      address: deployment.veMEZO,
      abi: veMezoAbi,
      functionName: "ownerToNFTokenIdList" as const,
      args: [owner!, index] as const,
    })),
    query: { enabled: indexes.length > 0 },
  });
  return (data ?? []).map((result) => result.result).filter((id): id is bigint => Boolean(id));
}

function lockReads(deployment: Deployment, tokenId: bigint) {
  const ve = { address: deployment.veMEZO, abi: veMezoAbi } as const;
  return [
    { ...ve, functionName: "locked", args: [tokenId] },
    { ...ve, functionName: "escrowType", args: [tokenId] },
    { ...ve, functionName: "vestingEnd", args: [tokenId] },
    { ...ve, functionName: "voted", args: [tokenId] },
    { ...ve, functionName: "getApproved", args: [tokenId] },
    { address: deployment.boostVoter, abi: boostVoterAbi, functionName: "lastVoted", args: [tokenId] },
  ] as const;
}

function toReads(values: unknown[]): LockReads {
  const [locked, escrowType, vestingEnd, voted, approved, lastVoted] = values;
  return {
    locked: locked as LockReads["locked"],
    escrowType: Number(escrowType ?? 0),
    vestingEnd: (vestingEnd as bigint) ?? 0n,
    voted: Boolean(voted),
    approved: (approved as Address) ?? "0x0000000000000000000000000000000000000000",
    lastVoted: (lastVoted as bigint) ?? 0n,
  };
}
