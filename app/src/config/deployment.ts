import type { Address } from "viem";

export interface Deployment {
  chainId: number;
  vault: Address;
  stMEZO: Address;
  staking: Address;
  harvester: Address;
  veMEZO: Address;
  boostVoter: Address;
  musd: Address;
  mezo: Address;
}

/** Deployment files written by `forge script DeployLockless`. Empty until the first deploy. */
const files = import.meta.glob<Deployment>("../../../contracts/deployments/*.json", {
  eager: true,
  import: "default",
});

export const deployment: Deployment | null =
  Object.values(files).find((file) => file.chainId === 31611) ?? null;
