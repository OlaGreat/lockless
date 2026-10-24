/** The parts of a wagmi connector the wallet picker needs. */
export interface DetectedConnector {
  id: string;
  name: string;
  type: string;
  icon?: string;
}

export interface WalletOption {
  id: string;
  name: string;
  icon?: string;
}

/** wagmi's id for the connector that talks to whatever wallet owns `window.ethereum`. */
const GENERIC_INJECTED_ID = "injected";

/**
 * The wallets to offer the user. Wallets that announce themselves (EIP-6963) are listed by name.
 * The generic `window.ethereum` connector is only offered when no wallet announced itself,
 * because with several extensions installed it reaches an arbitrary one.
 */
export function walletOptions(connectors: readonly DetectedConnector[]): WalletOption[] {
  const announced = uniqueById(connectors.filter((connector) => !isGeneric(connector)));
  if (announced.length > 0) return announced.map(toOption);

  const generic = connectors.find(isGeneric);
  return generic ? [{ id: generic.id, name: "Browser wallet", icon: generic.icon }] : [];
}

function isGeneric(connector: DetectedConnector): boolean {
  return connector.id === GENERIC_INJECTED_ID;
}

function uniqueById(connectors: DetectedConnector[]): DetectedConnector[] {
  const seen = new Set<string>();
  return connectors.filter((connector) => {
    if (seen.has(connector.id)) return false;
    seen.add(connector.id);
    return true;
  });
}

function toOption(connector: DetectedConnector): WalletOption {
  return { id: connector.id, name: connector.name, icon: connector.icon };
}
