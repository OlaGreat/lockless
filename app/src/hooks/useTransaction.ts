import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import type { Hash } from "viem";
import { usePublicClient, useWriteContract } from "wagmi";

export type TxState =
  | { status: "idle" }
  | { status: "pending"; label: string }
  | { status: "success"; label: string; hash: Hash }
  | { status: "error"; message: string };

type WriteRequest = Parameters<ReturnType<typeof useWriteContract>["writeContractAsync"]>[0];

/** Sends a transaction, waits for it, then refreshes every on-chain read. */
export function useTransaction() {
  const { writeContractAsync } = useWriteContract();
  const publicClient = usePublicClient();
  const queryClient = useQueryClient();
  const [state, setState] = useState<TxState>({ status: "idle" });

  async function send(label: string, request: WriteRequest): Promise<void> {
    setState({ status: "pending", label });
    try {
      const hash = await writeContractAsync(request);
      await publicClient!.waitForTransactionReceipt({ hash });
      setState({ status: "success", label, hash });
      await queryClient.invalidateQueries();
    } catch (error) {
      setState({ status: "error", message: shortError(error) });
    }
  }

  return { state, send, busy: state.status === "pending" };
}

function shortError(error: unknown): string {
  const details = error as { shortMessage?: string; message?: string };
  return details.shortMessage ?? details.message?.split("\n")[0] ?? "Transaction failed";
}
