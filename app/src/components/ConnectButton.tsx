import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { mezoTestnet } from "../config/chain";
import { shortAddress } from "../lib/format";

/** Connects a browser wallet and keeps it on Mezo testnet. */
export function ConnectButton() {
  const { address, chainId, isConnected } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();

  if (!isConnected) {
    const injected = connectors[0];
    return (
      <button className="button" disabled={!injected || isPending} onClick={() => injected && connect({ connector: injected })}>
        {isPending ? "Connecting…" : "Connect wallet"}
      </button>
    );
  }
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
