import { useState } from "react";
import type { Address } from "viem";
import { erc20Abi, vaultAbi } from "../config/abis";
import type { Deployment } from "../config/deployment";
import { useTokenAccount } from "../hooks/useTokenAccount";
import { useTransaction } from "../hooks/useTransaction";
import { amountError, parseAmount } from "../lib/amount";
import { AmountField } from "./AmountField";
import { TxStatus } from "./TxStatus";

/** Lock MEZO into the master lock and receive stMEZO one for one. */
export function DepositPanel({ deployment, account }: { deployment: Deployment; account: Address }) {
  const [value, setValue] = useState("");
  const { balance, allowance } = useTokenAccount(deployment.mezo, account, deployment.vault);
  const tx = useTransaction();
  const amount = parseAmount(value) ?? 0n;
  const ready = amountError(value, balance) === null;
  const needsApproval = allowance < amount;

  function submit() {
    if (needsApproval) {
      return tx.send("Approve MEZO", { address: deployment.mezo, abi: erc20Abi, functionName: "approve", args: [deployment.vault, amount] });
    }
    return tx.send("Deposit", { address: deployment.vault, abi: vaultAbi, functionName: "deposit", args: [amount, account] });
  }

  return (
    <div className="panel">
      <p className="panel__intro">
        Your MEZO joins Lockless's permanent veMEZO lock. You get the same amount of stMEZO, which you can trade at
        any time or stake to earn the incentives the lock collects, paid in MUSD.
      </p>
      <AmountField label="Deposit MEZO" symbol="MEZO" balance={balance} value={value} onChange={setValue} />
      <button className="button button--wide" disabled={!ready || tx.busy} onClick={submit}>
        {needsApproval ? "Approve MEZO" : "Deposit and get stMEZO"}
      </button>
      <TxStatus state={tx.state} />
    </div>
  );
}
