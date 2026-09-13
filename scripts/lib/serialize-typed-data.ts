/**
 * Recursively converts every `bigint` in a value to its decimal string form, so EIP-712 typed
 * data built by the x402 EVM scheme (whose `message` fields such as `value`/`validAfter`/
 * `validBefore` are `bigint`) can round-trip through `JSON.stringify` on the way to the backend.
 */
export function serializeBigInts<T>(value: T): T {
  if (typeof value === 'bigint') {
    return value.toString() as unknown as T;
  }
  if (Array.isArray(value)) {
    return value.map((entry) => serializeBigInts(entry)) as unknown as T;
  }
  if (value !== null && typeof value === 'object') {
    const result: Record<string, unknown> = {};
    for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
      result[key] = serializeBigInts(entry);
    }
    return result as T;
  }
  return value;
}
