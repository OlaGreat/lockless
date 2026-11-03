import type { ContractFunctionArgs } from "viem";
import { useReadContract } from "wagmi";
import { routerAbi } from "../config/abis";
import type { Deployment } from "../config/deployment";
import { sellRoute, type Route } from "../lib/sellQuote";

type QuoteArgs = ContractFunctionArgs<typeof routerAbi, "view", "getAmountsOut">;

/** What the stMEZO/MEZO pool on Mezo Pools pays for an amount of stMEZO right now. */
export function useSellQuote(deployment: Deployment, amount: bigint): { routes: Route[]; quoted: bigint } {
  const { data: factory } = useReadContract({
    address: deployment.router,
    abi: routerAbi,
    functionName: "defaultFactory",
  });
  const routes: Route[] = factory ? sellRoute(deployment.stMEZO, deployment.mezo, factory) : [];
  const args: QuoteArgs = [amount, routes];
  const { data: amounts } = useReadContract({
    address: deployment.router,
    abi: routerAbi,
    functionName: "getAmountsOut",
    args,
    query: { enabled: routes.length > 0 && amount > 0n },
  });
  return { routes, quoted: amounts?.at(-1) ?? 0n };
}
