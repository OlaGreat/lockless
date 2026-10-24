import { useState } from "react";
import { useAccount, useConnect, useConnectors, useDisconnect, useSwitchChain } from "wagmi";
import { mezoTestnet } from "../config/chain";
import { shortAddress } from "../lib/format";
import { connectionErrorMessage, walletOptions } from "../lib/wallets";
import { WalletPicker } from "./WalletPicker";

/** Lets the user pick one of their installed wallets and keeps it on Mezo testnet. */
export function ConnectButton() {
  const { address, chainId, isConnected } = useAccount();
  const { switchChain } = useSwitchChain();
  const { disconnect } = useDisconnect();

  if (!isConnected) return <WalletConnect />;
  if (chainId !== mezoTestnet.id) {
    return (
      <button className="button button--warning" onClick={() => switchChain({ chainId: mezoTestnet.id })}>
        Switch to Mezo testnet
      </button>
    );
  }
  return (
    <button className="button button--ghost" onClick={() => disconnect()} title="Disconnect">
      {shortAddress(address!)}
    </button>
  );
}

function WalletConnect() {
  const connectors = useConnectors();
  const { connect, error, isPending, reset } = useConnect();
  const [open, setOpen] = useState(false);
  const [selectedId, setSelectedId] = useState<string>();
  const options = walletOptions(connectors);
  const selectedName = options.find((option) => option.id === selectedId)?.name ?? "Wallet";

  function openPicker() {
    reset();
    setOpen(true);
  }

  function select(id: string) {
    const connector = connectors.find((candidate) => candidate.id === id);
    if (!connector) return;
    setSelectedId(id);
    connect({ connector });
  }

  return (
    <>
      <button className="button" onClick={openPicker}>
        Connect wallet
      </button>
      {open && (
        <WalletPicker
          options={options}
          onSelect={select}
          onClose={() => setOpen(false)}
          pendingId={isPending ? selectedId : undefined}
          error={error ? connectionErrorMessage(selectedName, error) : undefined}
        />
      )}
    </>
  );
}
