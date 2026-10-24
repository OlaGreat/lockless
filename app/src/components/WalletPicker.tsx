import type { WalletOption } from "../lib/wallets";

interface WalletPickerProps {
  options: WalletOption[];
  onSelect: (id: string) => void;
  onClose: () => void;
  pendingId?: string;
  error?: string;
}

const INSTALL_LINK = "https://metamask.io/download/";

/** A dialog listing the wallets installed in the browser so the user picks one. */
export function WalletPicker({ options, onSelect, onClose, pendingId, error }: WalletPickerProps) {
  return (
    <div className="dialog-backdrop" onClick={onClose}>
      <div
        className="dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="wallet-picker-title"
        onClick={(event) => event.stopPropagation()}
      >
        <header className="dialog__header">
          <h2 id="wallet-picker-title">Connect a wallet</h2>
          <button className="dialog__close" aria-label="Close" onClick={onClose}>
            ×
          </button>
        </header>
        {options.length === 0 ? <NoWallet /> : <WalletList {...{ options, onSelect, pendingId }} />}
        {error && (
          <p role="alert" className="field-error">
            {error}
          </p>
        )}
      </div>
    </div>
  );
}

function WalletList({ options, onSelect, pendingId }: Pick<WalletPickerProps, "options" | "onSelect" | "pendingId">) {
  return (
    <ul className="wallets">
      {options.map((option) => (
        <li key={option.id}>
          <button
            className="wallet"
            disabled={pendingId !== undefined}
            onClick={() => onSelect(option.id)}
          >
            {option.icon ? <img src={option.icon} alt={option.name} /> : <span className="wallet__blank" />}
            <span>{option.name}</span>
            {pendingId === option.id && <span className="muted">Connecting…</span>}
          </button>
        </li>
      ))}
    </ul>
  );
}

function NoWallet() {
  return (
    <p className="muted">
      No wallet found in this browser. Install{" "}
      <a href={INSTALL_LINK} target="_blank" rel="noreferrer">
        MetaMask
      </a>{" "}
      or another EVM wallet, then reload this page.
    </p>
  );
}
