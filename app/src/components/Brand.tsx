import { publicAsset } from "../lib/publicAsset";

/** The Lockless logo mark and name, as shown in the page header. */
export function Brand() {
  return (
    <div className="brand">
      <img className="brand__mark" src={publicAsset("logo-mark.svg")} alt="" />
      <span>Lockless</span>
    </div>
  );
}
