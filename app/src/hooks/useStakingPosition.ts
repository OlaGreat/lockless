import type { Address } from "viem";
import { useReadContracts } from "wagmi";
import { stakingAbi } from "../config/abis";
import type { Deployment } from "../config/deployment";

const ZERO = "0x0000000000000000000000000000000000000000";

/** A wallet's staked stMEZO and the MUSD and stMEZO it has earned. */
export function useStakingPosition(deployment: Deployment, account: Address | undefined) {
  const owner = account ?? ZERO;
  const staking = { address: deployment.staking, abi: stakingAbi } as const;
  const { data } = useReadContracts({
    contracts: [
      { ...staking, functionName: "balanceOf", args: [owner] },
      { ...staking, functionName: "earned", args: [owner, deployment.musd] },
      { ...staking, functionName: "earned", args: [owner, deployment.stMEZO] },
    ],
    query: { enabled: Boolean(account), refetchInterval: 15_000 },
  });
  return {
    staked: data?.[0]?.result ?? 0n,
    earnedMusd: data?.[1]?.result ?? 0n,
    earnedStMezo: data?.[2]?.result ?? 0n,
  };
}
