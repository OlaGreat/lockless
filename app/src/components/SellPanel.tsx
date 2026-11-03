import { useState } from "react";
import type { Address } from "viem";
import { erc20Abi, routerAbi } from "../config/abis";
import type { Deployment } from "../config/deployment";
import { useSellQuote } from "../hooks/useSellQuote";
import { useTokenAccount } from "../hooks/useTokenAccount";
import { useTransaction } from "../hooks/useTransaction";
import { amountError, parseAmount } from "../lib/amount";
import { formatToken } from "../lib/format";
import { describePriceVsPar, minimumReceived, swapDeadline } from "../lib/sellQuote";
import { AmountField } from "./AmountField";
import { TxStatus } from "./TxStatus";

/** Sell stMEZO for MEZO in the stMEZO/MEZO pool on Mezo Pools, the way holders leave. */
export function SellPanel({ deployment, account }: { deployment: Deployment; account: Address }) {
  const [value, setValue] = useState("");
  const { balance, allowance } = useTokenAccount(deployment.stMEZO, account, deployment.router);
  const amount = parseAmount(value) ?? 0n;
  const quote = useSellQuote(deployment, amount);
  const tx = useTransaction();
  const ready = amountError(value, balance) === null && quote.quoted > 0n;
  const needsApproval = allowance < amount;

  function submit() {
    if (needsApproval) {
      return tx.send("Approve stMEZO", {
        address: deployment.stMEZO,
        abi: erc20Abi,
        functionName: "approve",
        args: [deployment.router, amount],
      });
    }
    const deadline = swapDeadline(Math.floor(Date.now() / 1000));
    return tx.send("Sell stMEZO", {
      address: deployment.router,
      abi: routerAbi,
      functionName: "swapExactTokensForTokens",
      args: [amount, minimumReceived(quote.quoted), quote.routes, account, deadline],
    });
  }

  return (
    <div className="panel">
      <p className="panel__intro">
        stMEZO cannot be redeemed for MEZO, because Lockless's lock is permanent. You leave by selling stMEZO for
        MEZO in the stMEZO/MEZO pool on Mezo Pools, at whatever price the pool pays. Unstake first if your stMEZO is
        staked.
      </p>
      <AmountField label="Sell stMEZO" symbol="stMEZO" balance={balance} value={value} onChange={setValue} />
      <SellQuote amount={amount} quoted={quote.quoted} />
      <button className="button button--wide" disabled={!ready || tx.busy} onClick={submit}>
        {needsApproval ? "Approve stMEZO" : "Sell for MEZO"}
      </button>
      <TxStatus state={tx.state} />
    </div>
  );
}

function SellQuote({ amount, quoted }: { amount: bigint; quoted: bigint }) {
  if (amount === 0n) return null;
  if (quoted === 0n) return <p className="muted">The pool has no liquidity for this trade yet.</p>;
  return (
    <dl className="quote">
      <div>
        <dt className="muted">You get about</dt>
        <dd>{formatToken(quoted)} MEZO</dd>
      </div>
      <div>
        <dt className="muted">Price</dt>
        <dd>{describePriceVsPar(amount, quoted)}</dd>
      </div>
      <div>
        <dt className="muted">At least, after 1% slippage</dt>
        <dd>{formatToken(minimumReceived(quoted))} MEZO</dd>
      </div>
    </dl>
  );
}
