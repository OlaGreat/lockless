import type { ContractFunctionArgs } from "viem";
import { useReadContract, useReadContracts } from "wagmi";
import { routerAbi, stakingAbi } from "../config/abis";
import type { Deployment } from "../config/deployment";
import { stakingAprBps, type Stream } from "../lib/stakingApr";

const REFRESH_MS = 15_000;
const ONE_MEZO = 10n ** 18n;
const NO_STREAM: Stream = { ratePerSecond: 0n, periodFinish: 0n };

type QuoteArgs = ContractFunctionArgs<typeof routerAbi, "view", "getAmountsOut">;

/** The live staking APR in basis points, or undefined until there is a stake and a MEZO price. */
export function useStakingApr(deployment: Deployment): bigint | undefined {
  const streams = useRewardStreams(deployment);
  const mezoPriceInMusd = useMezoPriceInMusd(deployment);
  if (!streams || mezoPriceInMusd === undefined) return undefined;
  return stakingAprBps({ ...streams, mezoPriceInMusd, now: BigInt(Math.floor(Date.now() / 1000)) });
}

function useRewardStreams(deployment: Deployment) {
  const staking = { address: deployment.staking, abi: stakingAbi } as const;
  const { data } = useReadContracts({
    contracts: [
      { ...staking, functionName: "rewardData", args: [deployment.musd] },
      { ...staking, functionName: "rewardData", args: [deployment.stMEZO] },
      { ...staking, functionName: "totalStaked" },
    ],
    query: { refetchInterval: REFRESH_MS },
  });
  const totalStaked = data?.[2]?.result;
  if (totalStaked === undefined) return undefined;
  return { musd: toStream(data?.[0]?.result), stMezo: toStream(data?.[1]?.result), totalStaked };
}

/** MUSD the MEZO/MUSD pool on Mezo Pools pays for one MEZO, scaled by 1e18. */
function useMezoPriceInMusd(deployment: Deployment): bigint | undefined {
  const { data: factory } = useReadContract({
    address: deployment.router,
    abi: routerAbi,
    functionName: "defaultFactory",
  });
  const args: QuoteArgs = [ONE_MEZO, [{ from: deployment.mezo, to: deployment.musd, stable: false, factory: factory! }]];
  const { data: amounts } = useReadContract({
    address: deployment.router,
    abi: routerAbi,
    functionName: "getAmountsOut",
    args,
    query: { enabled: Boolean(factory), refetchInterval: REFRESH_MS },
  });
  return amounts?.at(-1);
}

function toStream(data: readonly [string, bigint, bigint, bigint, bigint, bigint] | undefined): Stream {
  if (!data) return NO_STREAM;
  return { periodFinish: data[2], ratePerSecond: data[3] };
}
