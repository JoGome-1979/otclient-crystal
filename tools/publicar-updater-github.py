#!/usr/bin/env python3
"""Create a pinned updater manifest from Git blobs, never from working-tree bytes."""
import argparse, json, pathlib, re, subprocess, tempfile, urllib.request, zlib, os
ROOT = pathlib.Path(__file__).resolve().parents[1]
REPO = 'JoGome-1979/otclient-crystal'

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])

def crc(content):
    return format(zlib.crc32(content) & 0xffffffff, 'x')

def eligible(path):
    if not (path == 'init.lua' or path.startswith(('data/', 'modules/', 'mods/'))):
        return False
    if any(part in ('.', '..', '') for part in path.split('/')) or '\\' in path:
        return False
    if any(ord(c) < 32 for c in path):
        return False
    if path.startswith('modules/game_paperdolls/server/'):
        return False
    return not re.search(r'\.(exe|dll|apk|ipa|dylib|dmg|pkg|deb|rpm|pdb|so(?:\.[0-9]+)*)$|\.app(?:/|$)', path, re.I)

def generate(commit):
    sha = git('rev-parse', '--verify', commit + '^{commit}').decode().strip()
    if not re.fullmatch('[a-f0-9]{40}', sha):
        raise ValueError('Commit SHA invalido')
    entries = git('ls-tree', '-rz', sha, '--', 'init.lua', 'data', 'modules', 'mods').split(b'\0')
    files = {}; probes = {}
    process = subprocess.Popen(['git', '-C', str(ROOT), 'cat-file', '--batch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    try:
        for entry in entries:
            if not entry: continue
            header, name = entry.split(b'\t', 1); mode, kind, oid = header.split()
            path = name.decode('utf-8')
            if kind != b'blob' or mode not in (b'100644', b'100755') or not eligible(path): continue
            process.stdin.write(oid + b'\n'); process.stdin.flush()
            meta = process.stdout.readline().split()
            if len(meta) != 3 or meta[1] != b'blob': raise ValueError('Blob Git invalido')
            content = process.stdout.read(int(meta[2])); assert process.stdout.read(1) == b'\n'
            if content.startswith(b'version https://git-lfs.github.com/spec/v1\n'):
                raise ValueError('Git LFS precisa de hospedagem propria: ' + path)
            files['/' + path] = crc(content)
            if path in ('init.lua', 'modules/updater/updater.lua'): probes[path] = content
        process.stdin.close(); assert process.wait() == 0
    finally:
        if process.poll() is None: process.kill(); process.wait()
    if not all(k in probes for k in ('init.lua', 'modules/updater/updater.lua')):
        raise ValueError('Commit sem init.lua ou updater.lua')
    if not re.search(rb'updaterProtocol\s*=\s*2', probes['modules/updater/updater.lua']):
        raise ValueError('Commit ainda nao contem o updater com suporte ao GitHub. Commit/push as alteracoes primeiro.')
    return {'schema': 1, 'repository': REPO, 'commit': sha, 'files': dict(sorted(files.items()))}, probes

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--commit', default='HEAD')
    parser.add_argument('--output', type=pathlib.Path, default=ROOT/'build/updater/github-release.json')
    args = parser.parse_args()
    release, probes = generate(args.commit)
    base = f"https://raw.githubusercontent.com/{REPO}/{release['commit']}/"
    # Public reachability and exact bytes must match before producing a publishable manifest.
    for path, expected in probes.items():
        from urllib.parse import quote
        with urllib.request.urlopen(base + quote(path, safe='/'), timeout=45) as response:
            if response.read() != expected: raise ValueError('GitHub difere do commit local: ' + path)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=args.output.parent, prefix='.github-release-')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(release, stream, ensure_ascii=False, indent=2); stream.write('\n')
        os.chmod(temporary, 0o644)
        os.replace(temporary, args.output)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)
    print('Commit:', release['commit']); print('Arquivos GitHub:', len(release['files'])); print('Manifesto:', args.output)
    print('Publique o manifesto como api/github-release.json na VPS. Os binarios continuam em api/files/.')

if __name__ == '__main__':
    try: main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error: raise SystemExit(str(error))
