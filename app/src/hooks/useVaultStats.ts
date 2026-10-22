import { useReadContract, useReadContracts } from "wagmi";
import { erc20Abi, stakingAbi, vaultAbi, veMezoAbi } from "../config/abis";
import type { Deployment } from "../config/deployment";

const REFRESH_MS = 15_000;

export interface VaultStats {
  lockedMezo?: bigint;
  stMezoSupply?: bigint;
  stakedStMezo?: bigint;
  masterTokenId?: bigint;
  votingPower?: bigint;
}

/** Protocol-wide numbers for the stats bar. */
export function useVaultStats(deployment: Deployment): VaultStats {
  const { data } = useReadContracts({
    contracts: [
      { address: deployment.vault, abi: vaultAbi, functionName: "lockedAmount" },
      { address: deployment.stMEZO, abi: erc20Abi, functionName: "totalSupply" },
      { address: deployment.staking, abi: stakingAbi, functionName: "totalStaked" },
      { address: deployment.vault, abi: vaultAbi, functionName: "masterTokenId" },
    ],
    query: { refetchInterval: REFRESH_MS },
  });
  const masterTokenId = data?.[3]?.result;
  const { data: votingPower } = useReadContract({
    address: deployment.veMEZO,
    abi: veMezoAbi,
    functionName: "votingPowerOfNFT",
    args: [masterTokenId ?? 0n],
    query: { enabled: Boolean(masterTokenId), refetchInterval: REFRESH_MS },
  });
  return {
    lockedMezo: data?.[0]?.result,
    stMezoSupply: data?.[1]?.result,
    stakedStMezo: data?.[2]?.result,
    masterTokenId,
    votingPower,
  };
}
