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

// Per-device presentation metadata (display name, product photo, optional warning
// note), keyed by the board slug parsed out of the image filename above. Emitted both
// as a top-level `devices` catalog AND inlined on each asset so the website can render
// a device card with `<img src=asset.image>` and show `asset.note`. Images are public
// hotlinks from CDNs that allow it and were verified to return image/* — NOT openwrt.org
// (its _media / fetch.php paths serve text/html, so they render broken as <img src>).
// Blank `image` = no hotlinkable public source found (self-hosting was declined for repo
// size); the site falls back to its own placeholder. `note` is a per-device caveat
// the site can badge (experimental / limited support); omit it when there's nothing to
// flag. The router OTA picker ignores all three fields (reads only board/openwrt/file/
// sha256), so this is presentation-only and safe to add.
const EAP225_NOTE = '⚠ Experimental — single-port AP-as-gateway image, not yet boot-tested on hardware. Flash only on a device you can recover, and verify one revision (internet + portal + a client session) first.';
const DEVICES = {
  'asus-rt-ax52':               { name: 'ASUS RT-AX52',               image: 'https://image.alza.cz/products/Asus23_022/Asus23_022-01.jpg' },
  'asus-rt-ac68u':              { name: 'ASUS RT-AC68U',              image: 'https://dlcdnwebimgs.asus.com/gain/6670e848-ba84-47e0-97d5-fd076ac3a137/w185', note: '⚠ Wi-Fi unsupported on this Broadcom board in OpenWrt — routes over Ethernet only and cannot serve its own hotspot. Use it wired or paired with an external AP node. First flash from stock ASUS uses the .trx (this image is that .trx under a .bin name).' },
  'comfast-cf-n5-v2':           { name: 'Comfast CF-N5 v2',           image: 'https://comfastgroup.com/wp-content/uploads/2024/09/cf-n5-v2.webp' },
  'comfast-cf-ew71-v2':         { name: 'Comfast CF-EW71 v2',         image: '' },
  'comfast-cf-ew72-v2':         { name: 'Comfast CF-EW72 v2',         image: 'https://comfastgroup.com/wp-content/uploads/2024/09/cf-ew72-v2.webp' },
  'edup-ep-rt2983':             { name: 'EDUP EP-RT2983',             image: '' },
  'linksys-ea8300':             { name: 'Linksys EA8300',             image: '' },
  'linksys-wrt1900acs':         { name: 'Linksys WRT1900ACS',         image: '' },
  'mercusys-mr70x-v1':          { name: 'Mercusys MR70X v1',          image: 'https://static.mercusys.com/product-image/01_large20201223072930.jpg' },
  'newifi-d2':                  { name: 'Newifi D2',                  image: '' },
  'ruijie-rg-ew1200g-pro-v1.1': { name: 'Ruijie RG-EW1200G PRO v1.1', image: 'https://eo-sgp-cos.ruijie.com/background/other/2023-10-27/7b9d778c2293490a993760bc68f52396.png' },
  'ruijie-rg-ew3200gx-pro':     { name: 'Ruijie RG-EW3200GX PRO',     image: 'https://eo-sgp-cos.ruijie.com/background/other/2023-10-30/b2b529094b4d432fa998eba11a445b19.png' },
  'zbt-wg3526-16m':             { name: 'ZBT WG3526 (16M)',           image: '' },
  // TP-Link EAP225 single-port family — TP-Link's CDN blocks hotlinking (HTTP 403),
  // so no working public img src; host a photo in release/img/ to fill these.
  // (No eap225-v2: v2 hardware has no separate OpenWrt profile and flashes the v1 image.)
  'eap225-v1':                  { name: 'TP-Link EAP225 v1',          image: '', note: EAP225_NOTE },
  'eap225-v3':                  { name: 'TP-Link EAP225 v3',          image: '', note: EAP225_NOTE },
  'eap225-v4':                  { name: 'TP-Link EAP225 v4',          image: '', note: EAP225_NOTE },
  'eap225-outdoor-v1':          { name: 'TP-Link EAP225-Outdoor v1',  image: '', note: EAP225_NOTE },
  'eap225-outdoor-v3':          { name: 'TP-Link EAP225-Outdoor v3',  image: '', note: EAP225_NOTE },
  'eap225-wall-v2':             { name: 'TP-Link EAP225-Wall v2',     image: '', note: EAP225_NOTE },
};

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
    const meta = DEVICES[board] || { name: board, image: '', note: '' };
    assets.push({ board, name: meta.name, openwrt, file: name, sha256, image: meta.image || '', note: meta.note || '' });
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
// top-level catalog: board slug -> { name, image, note } (normalized so every entry
// has all three keys, even when the DEVICES map omitted an empty image/note).
out.devices = Object.fromEntries(
  Object.entries(DEVICES).map(([k, v]) => [k, { name: v.name, image: v.image || '', note: v.note || '' }]),
);
process.stdout.write(JSON.stringify(out, null, 2) + '\n');
