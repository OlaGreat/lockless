import { formatUnits } from "viem";
import { amountError } from "../lib/amount";
import { formatToken } from "../lib/format";

interface AmountFieldProps {
  label: string;
  symbol: string;
  balance: bigint;
  value: string;
  onChange: (value: string) => void;
}

/** A token amount input with the balance, a Max shortcut and a validation message. */
export function AmountField({ label, symbol, balance, value, onChange }: AmountFieldProps) {
  const error = value === "" ? null : amountError(value, balance);
  return (
    <div className="amount-field">
      <div className="amount-field__top">
        <label htmlFor={`amount-${label}`}>{label}</label>
        <span className="muted">
          Balance: {formatToken(balance)} {symbol}
        </span>
      </div>
      <div className="amount-field__input">
        <input
          id={`amount-${label}`}
          inputMode="decimal"
          placeholder="0.0"
          value={value}
          onChange={(event) => onChange(event.target.value)}
        />
        <button type="button" className="chip" onClick={() => onChange(formatUnits(balance, 18))}>
          Max
        </button>
      </div>
      {error && (
        <p role="alert" className="field-error">
          {error}
        </p>
      )}
    </div>
  );
}
