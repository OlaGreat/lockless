import { describe, expect, it } from "vitest";
import { lockRequest } from "./lockRequest";

const deployment = {
  vault: "0x9B137463d4E7986D7f535f9B79e28b4EF1938E9b",
  veMEZO: "0xaCE816CA2bcc9b12C59799dcC5A959Fb9b98111b",
  boostVoter: "0x21d7bDF5a5929AD179F8cA0c9014A0B62ae6Bfd1",
} as const;
const ACCOUNT = "0xFE2d98d719e5d23A04307c4C8d8Cc814c5fEF958";

describe("lockRequest", () => {
  it("converts through the vault, minting stMEZO to the user", () => {
    const request = lockRequest("convert", 7n, deployment, ACCOUNT);

    expect(request).toMatchObject({ address: deployment.vault, functionName: "depositLock", args: [7n, ACCOUNT] });
  });

  it("approves the vault on veMEZO", () => {
    const request = lockRequest("approve", 7n, deployment, ACCOUNT);

    expect(request).toMatchObject({ address: deployment.veMEZO, functionName: "approve", args: [deployment.vault, 7n] });
  });

  it("turns off a permanent lock on veMEZO", () => {
    expect(lockRequest("unlock-permanent", 7n, deployment, ACCOUNT)).toMatchObject({
      address: deployment.veMEZO,
      functionName: "unlockPermanent",
      args: [7n],
    });
  });

  it("resets old votes on the boost voter", () => {
    expect(lockRequest("reset-votes", 7n, deployment, ACCOUNT)).toMatchObject({
      address: deployment.boostVoter,
      functionName: "reset",
      args: [7n],
    });
  });

  it("sends nothing for steps the user cannot take now", () => {
    expect(lockRequest("wait-next-epoch", 7n, deployment, ACCOUNT)).toBeNull();
    expect(lockRequest("not-supported", 7n, deployment, ACCOUNT)).toBeNull();
  });
});
