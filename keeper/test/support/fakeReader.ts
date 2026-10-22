import type { ContractCall, ContractReader } from "../../src/mezo/reader";

type Key = string;

/** A chain stand-in: answers calls from a table keyed by address, function and arguments. */
export class FakeReader implements ContractReader {
  private readonly answers = new Map<Key, unknown>();
  readonly calls: ContractCall[] = [];

  on(address: string, functionName: string, args: readonly unknown[], result: unknown): this {
    this.answers.set(this.key(address, functionName, args), result);
    return this;
  }

  async readAll<T>(calls: ContractCall[]): Promise<T[]> {
    this.calls.push(...calls);
    return calls.map((call) => this.answer(call) as T);
  }

  private answer(call: ContractCall): unknown {
    const key = this.key(call.address, call.functionName, call.args ?? []);
    if (!this.answers.has(key)) throw new Error(`FakeReader has no answer for ${key}`);
    return this.answers.get(key);
  }

  private key(address: string, functionName: string, args: readonly unknown[]): Key {
    const printableArgs = args.map((arg) => String(arg).toLowerCase()).join(",");
    return `${address.toLowerCase()}.${functionName}(${printableArgs})`;
  }
}
