import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { mezoTestnet } from "./chain";

export const wagmiConfig = createConfig({
  chains: [mezoTestnet],
  connectors: [injected()],
  transports: { [mezoTestnet.id]: http() },
});
