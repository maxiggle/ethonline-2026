import * as fs from 'fs';
import * as path from 'path';
import { pathToFileURL } from 'url';
import { installIdkitWasmFileFetch } from './idkit-node-wasm-loader';

describe('installIdkitWasmFileFetch', () => {
  const tempWasmPath = path.join(__dirname, 'idkit_wasm_bg.wasm');

  beforeAll(() => {
    fs.writeFileSync(tempWasmPath, Buffer.from([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]));
  });

  afterAll(() => {
    if (fs.existsSync(tempWasmPath)) {
      fs.unlinkSync(tempWasmPath);
    }
  });

  it('installs idempotently and serves local wasm bytes for idkit_wasm_bg.wasm file URLs', async () => {
    installIdkitWasmFileFetch();
    installIdkitWasmFileFetch();

    const fileUrl = pathToFileURL(tempWasmPath).href;
    const response = await globalThis.fetch(fileUrl);

    expect(response.status).toBe(200);
    expect(response.headers.get('Content-Type')).toBe('application/wasm');

    const bytes = new Uint8Array(await response.arrayBuffer());
    expect(bytes[0]).toBe(0x00);
    expect(bytes[1]).toBe(0x61);
    expect(bytes[2]).toBe(0x73);
    expect(bytes[3]).toBe(0x6d);
  });

  it('delegates non-matching file URLs to default fetch handling', async () => {
    installIdkitWasmFileFetch();
    const nonMatchingFileUrl = pathToFileURL(path.join(__dirname, 'other.txt')).href;
    await expect(globalThis.fetch(nonMatchingFileUrl)).rejects.toThrow();
  });
});
