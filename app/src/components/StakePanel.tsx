import { useState } from "react";
import type { Address } from "viem";
import { erc20Abi, stakingAbi } from "../config/abis";
import type { Deployment } from "../config/deployment";
import { useStakingPosition } from "../hooks/useStakingPosition";
import { useTokenAccount } from "../hooks/useTokenAccount";
import { useTransaction } from "../hooks/useTransaction";
import { amountError, parseAmount } from "../lib/amount";
import { formatToken } from "../lib/format";
import { AmountField } from "./AmountField";
import { TxStatus } from "./TxStatus";

/** Stake stMEZO to earn MUSD incentives and stMEZO rebases, and claim them. */
export function StakePanel({ deployment, account }: { deployment: Deployment; account: Address }) {
  const [stakeValue, setStakeValue] = useState("");
  const [withdrawValue, setWithdrawValue] = useState("");
  const wallet = useTokenAccount(deployment.stMEZO, account, deployment.staking);
  const position = useStakingPosition(deployment, account);
  const tx = useTransaction();
  const staking = { address: deployment.staking, abi: stakingAbi } as const;

  const stakeAmount = parseAmount(stakeValue) ?? 0n;
  const withdrawAmount = parseAmount(withdrawValue) ?? 0n;
  const needsApproval = wallet.allowance < stakeAmount;
  const hasRewards = position.earnedMusd > 0n || position.earnedStMezo > 0n;

  function stake() {
    if (needsApproval) {
      return tx.send("Approve stMEZO", { address: deployment.stMEZO, abi: erc20Abi, functionName: "approve", args: [deployment.staking, stakeAmount] });
    }
    return tx.send("Stake", { ...staking, functionName: "stake", args: [stakeAmount] });
  }

  return (
    <div className="panel">
      <div className="earned">
        <div>
          <span className="muted">Staked</span>
          <strong>{formatToken(position.staked)} stMEZO</strong>
        </div>
        <div>
          <span className="muted">Earned</span>
          <strong>{formatToken(position.earnedMusd)} MUSD</strong>
          <strong>{formatToken(position.earnedStMezo)} stMEZO</strong>
        </div>
        <button className="button" disabled={!hasRewards || tx.busy} onClick={() => tx.send("Claim rewards", { ...staking, functionName: "claimRewards" })}>
          Claim
        </button>
      </div>

      <AmountField label="Stake stMEZO" symbol="stMEZO" balance={wallet.balance} value={stakeValue} onChange={setStakeValue} />
      <button className="button button--wide" disabled={amountError(stakeValue, wallet.balance) !== null || tx.busy} onClick={stake}>
        {needsApproval ? "Approve stMEZO" : "Stake"}
      </button>

      <AmountField label="Withdraw stMEZO" symbol="stMEZO" balance={position.staked} value={withdrawValue} onChange={setWithdrawValue} />
      <div className="row">
        <button className="button button--ghost" disabled={amountError(withdrawValue, position.staked) !== null || tx.busy} onClick={() => tx.send("Withdraw", { ...staking, functionName: "withdraw", args: [withdrawAmount] })}>
          Withdraw
        </button>
        <button className="button button--ghost" disabled={position.staked === 0n || tx.busy} onClick={() => tx.send("Exit", { ...staking, functionName: "exit" })}>
          Withdraw all and claim
        </button>
      </div>
      <TxStatus state={tx.state} />
    </div>
  );
}
