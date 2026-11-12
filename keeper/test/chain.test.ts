import type { PublicClient, WalletClient } from "viem";
import { describe, expect, it, vi } from "vitest";
import { gasWithHeadroom, sendAndWait, type WriteCall } from "../src/mezo/chain";

const HASH = "0xabc";
const CALL: WriteCall = {
  address: "0x0000000000000000000000000000000000000001",
  abi: [],
  functionName: "distribute",
  args: [],
};

function fakeClients(status: "success" | "reverted") {
  const reader = {
    estimateContractGas: vi.fn().mockResolvedValue(100_000n),
    waitForTransactionReceipt: vi.fn().mockResolvedValue({ status }),
  };
  const signer = { account: { address: "0x2" }, chain: { id: 31611 }, writeContract: vi.fn().mockResolvedValue(HASH) };
  return { reader, signer };
}

describe("gasWithHeadroom", () => {
  it("adds 30% to an estimate", () => {
    expect(gasWithHeadroom(100_000n)).toBe(130_000n);
  });
});

describe("sendAndWait", () => {
  it("sends with the estimate plus headroom", async () => {
    const { reader, signer } = fakeClients("success");

    await sendAndWait(reader as unknown as PublicClient, signer as unknown as WalletClient, CALL);

    expect(signer.writeContract).toHaveBeenCalledWith(expect.objectContaining({ gas: 130_000n }));
  });

  it("waits longer than the default for a slow node to show the receipt", async () => {
    const { reader, signer } = fakeClients("success");

    await sendAndWait(reader as unknown as PublicClient, signer as unknown as WalletClient, CALL);

    expect(reader.waitForTransactionReceipt).toHaveBeenCalledWith(
      expect.objectContaining({ hash: HASH, retryCount: 30 }),
    );
  });

  it("returns the explorer link", async () => {
    const { reader, signer } = fakeClients("success");

    const link = await sendAndWait(reader as unknown as PublicClient, signer as unknown as WalletClient, CALL);

    expect(link).toBe("https://explorer.test.mezo.org/tx/0xabc");
  });

  it("throws when the transaction reverts", async () => {
    const { reader, signer } = fakeClients("reverted");

    await expect(
      sendAndWait(reader as unknown as PublicClient, signer as unknown as WalletClient, CALL),
    ).rejects.toThrow("Transaction failed");
  });
});
