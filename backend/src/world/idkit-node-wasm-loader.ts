import * as fs from 'fs';
import { fileURLToPath } from 'url';

let isWasmFetchInstalled = false;

// Node's native fetch lacks file: URL support, which @worldcoin/idkit-core requires to initialize its WASM module.
export function installIdkitWasmFileFetch(): void {
  if (isWasmFetchInstalled) {
    return;
  }

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async function (
    input: RequestInfo | URL,
    init?: RequestInit,
  ): Promise<Response> {
    const urlString =
      typeof input === 'string'
        ? input
        : input instanceof URL
          ? input.href
          : (input as Request).url;

    if (urlString.startsWith('file:') && urlString.endsWith('/idkit_wasm_bg.wasm')) {
      const filePath = fileURLToPath(urlString);
      const wasmBytes = fs.readFileSync(filePath);
      return new Response(wasmBytes, {
        status: 200,
        statusText: 'OK',
        headers: { 'Content-Type': 'application/wasm' },
      });
    }

    return originalFetch(input, init);
  };

  isWasmFetchInstalled = true;
}
