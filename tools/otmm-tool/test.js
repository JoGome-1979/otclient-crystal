// Independent zlib implementation verifies interoperability with the C# codec.
const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');
const zlib = require('zlib');
const { spawnSync } = require('child_process');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ot-map-tests-'));
const file = name => path.join(root, name);
let checks = 0;
function run(mode, input, output, operation, success = true) {
    const result = spawnSync(path.join(__dirname, 'bin', 'Tests.exe'), [mode, file(input), file(output), operation], { encoding: 'utf8' });
    if (result.error) throw result.error;
    assert.strictEqual(result.status === 0, success, result.stderr);
    checks++;
}
try {
    const header = Buffer.alloc(22);
    header.write('OTMM'); header.writeUInt16LE(22, 4); header.writeUInt16LE(1, 6);
    header.writeUInt16LE(8, 12); header.write('OTMM 1.0', 14);
    const rawBlocks = [Buffer.alloc(12288, 255), require('crypto').randomBytes(12288)];
    function record(data, index) {
        const prefix = Buffer.alloc(7); prefix.writeUInt16LE(index * 64, 0); prefix[4] = index;
        prefix.writeUInt16LE(data.length, 5); return Buffer.concat([prefix, data]);
    }
    const sentinel = Buffer.alloc(5, 255);
    const original = Buffer.concat([header, ...rawBlocks.map((b, i) => record(zlib.deflateSync(b), i)), sentinel]);
    fs.writeFileSync(file('source.otmm'), original);
    run('otmm', 'source.otmm', 'map.raw', 'decompress');
    const expected = Buffer.concat([Buffer.from('OTMMRAW1'), header, ...rawBlocks.map(record), sentinel]);
    assert.deepStrictEqual(fs.readFileSync(file('map.raw')), expected); checks++;
    run('otmm', 'map.raw', 'roundtrip.otmm', 'compress');
    const packed = fs.readFileSync(file('roundtrip.otmm'));
    let offset = 22;
    for (const block of rawBlocks) {
        const length = packed.readUInt16LE(offset + 5);
        assert.deepStrictEqual(zlib.inflateSync(packed.subarray(offset + 7, offset + 7 + length)), block);
        offset += 7 + length; checks++;
    }
    assert.deepStrictEqual(packed.subarray(offset), sentinel);
    run('otmm', 'roundtrip.otmm', 'roundtrip.raw', 'decompress');
    assert.deepStrictEqual(fs.readFileSync(file('roundtrip.raw')), expected); checks++;
    for (const [name, data] of [
        ['truncated', original.subarray(0, original.length - 1)],
        ['trailing', Buffer.concat([original, Buffer.from([0])])],
        ['invalid', Buffer.from('this is not an otmm file')],
        ['checksum', (() => { const b = Buffer.from(original); b[22 + 7 + b.readUInt16LE(27) - 1] ^= 1; return b; })()],
        ['version', (() => { const b = Buffer.from(original); b.writeUInt16LE(2, 6); return b; })()]
    ]) {
        fs.writeFileSync(file(name), data); run('otmm', name, name + '.out', 'decompress', false);
    }
    run('otmm', 'source.otmm', 'source.otmm', 'decompress', false);
    const rootHeader = Buffer.alloc(17);
    rootHeader.writeUInt32LE(4, 1); rootHeader.writeUInt16LE(65535, 5); rootHeader.writeUInt16LE(65534, 7);
    rootHeader.writeUInt32LE(4, 9); rootHeader.writeUInt32LE(4, 13);
    const escape = bytes => Buffer.from([...bytes].flatMap(b => b >= 253 ? [253, b] : [b]));
    const map = Buffer.concat([Buffer.from([0, 0, 0, 0, 254]), escape(rootHeader), Buffer.from([254, 2]), escape(require('crypto').randomBytes(1024 * 1024)), Buffer.from([255, 255])]);
    fs.writeFileSync(file('world.otbm'), map);
    run('map', 'world.otbm', 'server.otbm', 'compress');
    assert.deepStrictEqual(zlib.gunzipSync(fs.readFileSync(file('server.otbm'))), map); checks++;
    fs.writeFileSync(file('node-gzip.otbm'), zlib.gzipSync(map));
    run('map', 'node-gzip.otbm', 'restored.otbm', 'decompress');
    assert.deepStrictEqual(fs.readFileSync(file('restored.otbm')), map); checks++;
    run('map', 'server.otbm', 'roundtrip-map.otbm', 'decompress');
    assert.deepStrictEqual(fs.readFileSync(file('roundtrip-map.otbm')), map); checks++;
    run('map', 'invalid', 'bad-header.otbm', 'compress', false);
    run('map', 'invalid', 'invalid.otbm', 'decompress', false);
    run('map', 'world.otbm', 'wrong-tab.otbm', 'decompress', false);
    run('map', 'server.otbm', 'double-gzip.otbm', 'compress', false);
    run('map', 'world.otbm', 'world.otbm', 'compress', false);
    run('map', 'world.otbm', 'server.otbm', 'compress', false);
    assert.deepStrictEqual(zlib.gunzipSync(fs.readFileSync(file('server.otbm'))), map); checks++;
    const gzip = zlib.gzipSync(map);
    for (const [name, data] of [
        ['gzip-truncated', gzip.subarray(0, gzip.length - 8)],
        ['gzip-half', gzip.subarray(0, Math.floor(gzip.length / 2))],
        ['gzip-crc', (() => { const b = Buffer.from(gzip); b[b.length - 8] ^= 1; return b; })()],
        ['gzip-size', (() => { const b = Buffer.from(gzip); b[b.length - 4] ^= 1; return b; })()],
        ['gzip-not-map', zlib.gzipSync(Buffer.from('not a map'))]
    ]) {
        fs.writeFileSync(file(name), data); run('map', name, name + '.out', 'decompress', false);
        assert(!fs.existsSync(file(name + '.out')), 'Falha deixou resultado parcial'); checks++;
    }
    run('ui', '', 'ui.png', '');
    fs.copyFileSync(file('ui.png'), path.join(__dirname, 'bin', 'interface.png'));
    console.log(`${checks} verificações passaram: OTMM/zlib, OTBM/GZIP, integridade, entradas inválidas e abertura das três abas.`);
} finally {
    assert(path.dirname(root) === path.resolve(os.tmpdir()) && path.basename(root).startsWith('ot-map-tests-'));
    fs.rmSync(root, { recursive: true, force: true });
}
