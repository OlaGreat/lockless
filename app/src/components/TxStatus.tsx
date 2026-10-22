import { EXPLORER_URL } from "../config/chain";
import type { TxState } from "../hooks/useTransaction";

/** One line telling the user what their last transaction did. */
export function TxStatus({ state }: { state: TxState }) {
  if (state.status === "idle") return null;
  if (state.status === "pending") return <p className="tx tx--pending">{state.label}: confirm in your wallet…</p>;
  if (state.status === "error") return <p className="tx tx--error">{state.message}</p>;
  return (
    <p className="tx tx--success">
      {state.label} done.{" "}
      <a href={`${EXPLORER_URL}/tx/${state.hash}`} target="_blank" rel="noreferrer">
        View on explorer
      </a>
    </p>
  );
}
