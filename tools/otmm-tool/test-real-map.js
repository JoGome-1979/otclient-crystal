const fs = require('fs');
const path = require('path');
const os = require('os');
const assert = require('assert');
const crypto = require('crypto');
const zlib = require('zlib');
const { Writable } = require('stream');
const { pipeline } = require('stream/promises');
const { spawnSync } = require('child_process');

async function hash(file, gzip) {
    const digest = crypto.createHash('sha256');
    let bytes = 0;
    const sink = new Writable({ write(chunk, encoding, done) { digest.update(chunk); bytes += chunk.length; done(); } });
    const streams = [fs.createReadStream(file)];
    if (gzip) streams.push(zlib.createGunzip());
    streams.push(sink); await pipeline(...streams);
    return { bytes, sha256: digest.digest('hex') };
}

function convert(input, output, operation) {
    const result = spawnSync(path.join(__dirname, 'bin', 'Tests.exe'), ['map', input, output, operation], { encoding: 'utf8' });
    if (result.error) throw result.error;
    assert.strictEqual(result.status, 0, result.stderr);
}

async function main() {
    const source = path.resolve(process.argv[2]);
    const output = path.resolve(process.argv[3]);
    assert(!fs.existsSync(output), 'O teste não sobrescreve mapas existentes.');
    fs.mkdirSync(path.dirname(output), { recursive: true });
    const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'ot-map-real-'));
    try {
        console.log('Descompactando a cópia real do mapa...');
        const sourceBefore = await hash(source, false);
        convert(source, output, 'decompress');
        const independent = await hash(source, true);
        const extracted = await hash(output, false);
        assert.deepStrictEqual(extracted, independent);
        console.log('Mapa extraído idêntico à descompactação independente. Testando a volta para GZIP...');
        const compressed = path.join(scratch, 'world.otbm');
        convert(output, compressed, 'compress');
        assert.deepStrictEqual(await hash(compressed, true), extracted);
        assert.deepStrictEqual(await hash(source, false), sourceBefore);
        // Walk the escaped node tree as the editor's BinaryNode reader does.
        let depth = 0, nodes = 0, escaped = false, position = 0, ended = false;
        for await (const chunk of fs.createReadStream(output)) {
            for (const byte of chunk) {
                if (position++ < 4) continue;
                assert(!ended, 'Dados após a raiz OTBM.');
                if (escaped) { escaped = false; continue; }
                if (byte === 0xfd) escaped = true;
                else if (byte === 0xfe) { depth++; nodes++; }
                else if (byte === 0xff) { assert(depth > 0); depth--; if (depth === 0) ended = true; }
                else assert(depth > 0);
            }
        }
        assert(ended && depth === 0 && !escaped);
        const report = { source, output, compressedBytes: sourceBefore.bytes, ...extracted, nodes,
            verification: 'C# GZIP -> OTBM matches Node zlib; C# OTBM -> GZIP matches Node zlib; balanced escaped OTBM tree; source unchanged',
            editorGui: 'Not exercised with the real map; file format checked against local editor source' };
        fs.writeFileSync(path.join(__dirname, 'bin', 'verificacao-mapa-real.json'), JSON.stringify(report, null, 2));
        console.log(JSON.stringify(report, null, 2));
    } finally {
        assert(path.dirname(scratch) === path.resolve(os.tmpdir()) && path.basename(scratch).startsWith('ot-map-real-'));
        fs.rmSync(scratch, { recursive: true, force: true });
    }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
