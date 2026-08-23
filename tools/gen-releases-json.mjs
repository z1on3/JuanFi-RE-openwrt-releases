#!/usr/bin/env node
// Generate releases.json (the OTA version list the routers read) from the
// GitHub releases of the releases repo. Requires the `gh` CLI, authenticated.
//
//   node tools/gen-releases-json.mjs [owner/repo] > releases.json
//
// For every release it reads the asset list + the release's SHA256SUMS.txt,
// keeps only the router firmware images (JuanFi-RE-<board>-<openwrt>-beta-<rel>.bin
// — ESP8266/node assets are skipped), derives {board, openwrt} from each filename,
// and emits the structure documented in docs/SYSTEM-UPDATE.md. Newest release first.
//
// The router matches an asset by board == cvfi_board_slug AND openwrt ==
// cvfi_openwrt_version, so the derivation here MUST match those slugs exactly.

import { execFileSync } from 'node:child_process';
import { readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const repo = process.argv[2] || 'z1on3/JuanFi-RE-openwrt-releases';
const gh = (args) => execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });

// Router image filename: JuanFi-RE-<board>-<openwrt>-beta-<rel>.bin
// board slugs contain dashes; the OpenWrt version is the N.N.N token before -beta-.
const IMG_RE = /^JuanFi-RE-(.+)-(\d+\.\d+\.\d+)-beta-(.+)\.bin$/;

function parseSums(text) {
  // Lines: "<sha256> *<filename>" (or two spaces). Basename may include a dir.
  const map = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^([0-9a-fA-F]{64})\s+\*?(.+)$/);
    if (m) { map[m[2].replace(/^.*\//, '')] = m[1].toLowerCase(); }
  }
  return map;
}

const releases = JSON.parse(gh(['release', 'list', '--repo', repo, '--json', 'tagName,name,publishedAt,isPrerelease']));
// gh release list returns newest-first already; keep that order.
const out = { latest: '', releases: [] };

for (const rel of releases) {
  const tag = rel.tagName;
  if (tag === 'patches') { continue; } // the patch-asset release is not an OTA version
  const view = JSON.parse(gh(['release', 'view', tag, '--repo', repo, '--json', 'assets']));
  const names = (view.assets || []).map((a) => a.name);
  if (!names.includes('SHA256SUMS.txt')) { continue; }

  // Download + parse SHA256SUMS.txt for this release (node tmp + fs; no shell utils).
  let sums = {};
  const tmp = join(tmpdir(), `cvfi-sums-${tag.replace(/[^\w.-]/g, '_')}.txt`);
  try {
    gh(['release', 'download', tag, '--repo', repo, '--pattern', 'SHA256SUMS.txt', '--output', tmp, '--clobber']);
    sums = parseSums(readFileSync(tmp, 'utf8'));
    rmSync(tmp, { force: true });
  } catch (e) {
    process.stderr.write(`warn: ${tag}: could not read SHA256SUMS.txt (${e.message})\n`);
  }

  const assets = [];
  for (const name of names) {
    const m = name.match(IMG_RE);
    if (!m) { continue; }               // not a router image
    const [, board, openwrt] = m;
    const sha256 = sums[name];
    if (!sha256) { continue; }           // no checksum -> unsafe to offer
    assets.push({ board, openwrt, file: name, sha256 });
  }
  if (!assets.length) { continue; }

  // Derive a display "version" from the tag (v0.3-beta -> 0.3-beta).
  const version = tag.replace(/^v/, '');
  out.releases.push({
    version,
    tag,
    date: (rel.publishedAt || '').slice(0, 10),
    notes: rel.name || '',
    assets,
  });
}

if (out.releases.length) { out.latest = out.releases[0].version; }
process.stdout.write(JSON.stringify(out, null, 2) + '\n');
