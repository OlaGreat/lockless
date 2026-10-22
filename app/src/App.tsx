import { useState } from "react";
import { useAccount } from "wagmi";
import { ConnectButton } from "./components/ConnectButton";
import { ConvertPanel } from "./components/ConvertPanel";
import { DepositPanel } from "./components/DepositPanel";
import { StakePanel } from "./components/StakePanel";
import { StatsBar } from "./components/StatsBar";
import { EXPLORER_URL, mezoTestnet } from "./config/chain";
import { deployment, type Deployment } from "./config/deployment";

const TABS = ["Deposit MEZO", "Convert a lock", "Stake"] as const;
type Tab = (typeof TABS)[number];

export function App() {
  return (
    <div className="page">
      <header className="topbar">
        <div className="brand">
          <span className="brand__mark" aria-hidden>◆</span> Lockless
        </div>
        <ConnectButton />
      </header>
      <section className="hero">
        <h1>Lock MEZO forever. Stay liquid.</h1>
        <p>
          Lockless holds one permanent veMEZO lock, votes it every week for the best boost incentives and pays
          stakers in MUSD. You hold stMEZO, a token you can trade at any time.
        </p>
      </section>
      {deployment ? <Protocol deployment={deployment} /> : <NotDeployed />}
    </div>
  );
}

function Protocol({ deployment }: { deployment: Deployment }) {
  const [tab, setTab] = useState<Tab>("Deposit MEZO");
  return (
    <>
      <StatsBar deployment={deployment} />
      <main className="card">
        <nav className="tabs" role="tablist">
          {TABS.map((name) => (
            <button key={name} role="tab" aria-selected={tab === name} className="tab" onClick={() => setTab(name)}>
              {name}
            </button>
          ))}
        </nav>
        <ActivePanel tab={tab} deployment={deployment} />
      </main>
      <Footer deployment={deployment} />
    </>
  );
}

function ActivePanel({ tab, deployment }: { tab: Tab; deployment: Deployment }) {
  const { address, chainId } = useAccount();
  if (!address) return <p className="panel muted">Connect a wallet to continue.</p>;
  if (chainId !== mezoTestnet.id) return <p className="panel muted">Switch your wallet to Mezo testnet.</p>;
  if (tab === "Deposit MEZO") return <DepositPanel deployment={deployment} account={address} />;
  if (tab === "Convert a lock") return <ConvertPanel deployment={deployment} account={address} />;
  return <StakePanel deployment={deployment} account={address} />;
}

function Footer({ deployment }: { deployment: Deployment }) {
  const links: [string, string][] = [
    ["Vault", deployment.vault],
    ["stMEZO", deployment.stMEZO],
    ["Staking", deployment.staking],
    ["Harvester", deployment.harvester],
  ];
  return (
    <footer className="footer">
      {links.map(([name, address]) => (
        <a key={name} href={`${EXPLORER_URL}/address/${address}`} target="_blank" rel="noreferrer">
          {name}
        </a>
      ))}
      <span className="muted">Mezo testnet</span>
    </footer>
  );
}

function NotDeployed() {
  return (
    <main className="card panel">
      <p>Lockless is not deployed yet. Run the deploy script, then reload this page.</p>
    </main>
  );
}
