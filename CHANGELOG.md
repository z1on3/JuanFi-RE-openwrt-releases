# Changelog

All notable changes to the JuanFi‑RE flashable releases are documented here.

## beta 0.3 — 2026-08-22

A large feature release across all three router images (CF‑N5 v2, RG‑EW1200G PRO
v1.1, and the RT‑AX52 dev‑kit). The ESP8266 coin‑acceptor node firmware is
**unchanged since v1.0** — no reflash needed.

> **Reflash note:** the CF‑N5 v2 image is built on the `zbtlink_zbt-wg3526-16m`
> profile (both radios). Coming from a different profile, use `sysupgrade -F -n`.

### LuCI removed ()
- The router images **no longer ship LuCI** (or any `luci-*` package). The CVFi
  admin is the only web UI; router‑level changes (new SSIDs, `sysupgrade`) are made
  over **SSH**, enabled at provisioning time via the CLI. This also **fixes a
  beta‑0.2 regression** where LuCI leaked into the images via an uncommitted build
  script. Images are smaller as a result.

### Monetization: Router‑Pro / Free tiers
- **Device tier awareness** — cache / sync / redeem with a tier badge; Free vs Pro.
- **Free‑tier limits** — 10 concurrent active sessions and a branding lock.
- **Router Pro** activation without an api_key via a rate‑limited redeem; cloud
  sync gated to Pro with a Reconnect (reactivate) step; Pro license owner + masked
  key readout. Router Pro, node slots, and Cloud Subscription are decoupled.

### SubVendo / node licensing
- **License‑gated node enrollment**; per‑node **slot enforcement** on the device.
- Subvendo license **carried through enrollment and bound per node** (masked key);
  enroll subvendo nodes **auth‑free via device_id**, rate‑limited redeem.
- **Revoke‑to‑release/reclaim** a node slot; License column + real owner readout.

### Remote‑AP VLAN binding
- `tbl_vendo.vlan_id` (schema **v23**): bind nodes to **AP SSIDs / VLANs** for
  portal auto‑select and node‑name branding; VLAN provisioning + enforcement;
  auto‑select the bound node by ingress VLAN subnet; searchable SSID combo in admin.

### Cloud sync + remote control ()
- Per‑operator cloud **auto‑register**; **config backup/restore**; a device **Cloud
  Remote Control** command poller; **fail‑safe per‑node cloud deauthorization**.

### Sessions & time
- **Immutable session‑expiry deadline** + operator **timezone** setting; clients
  **Expiry** column and a system time/timezone readout; **auto‑resume** a paused
  session instantly on portal reconnect.

### Admin UI
- Collapsible sidebar rail with the app **version in the footer**; redesigned
  sidebar header; reusable **show/hide password** field; **branding media
  lifecycle** (remove, deterministic uploads, live previews); one full‑width hero
  logo/banner; logout + debug‑logs moved into the sidebar.

### Housekeeping
- Removed the dead `server/` Worker; operator docs now point at the mt‑api backend.

## beta 0.2 — 2026-08-16

Router images bump to **beta 0.2** (OpenWrt 24.10.3). The ESP8266 coin‑acceptor
node firmware is **unchanged since v1.0** — no reflash needed.

### Devices
- Added a **dev‑kit / experimental** image for the ASUS **RT‑AX52** (the development
  reference board), built on **OpenWrt 25.12.0** (`mediatek/filogic`, aarch64).
  Published for testers; not on the 24.10.3 base of the other two boards.

### Anti‑tethering / hotspot re‑share protection
- **Downstream TTL/hop‑limit cap** drops traffic from devices re‑sharing the
  hotspot (the AdoPisoft method), matching the decremented TTL at the FORWARD hook.
- **TCP‑SYN‑fingerprint tether detector** (`cvfi_tether_scan`) with selectable
  enforcement — **off / log / kick** — wired into cron. (The experimental
  timestamp‑clock same‑OS signal was trialled and reverted as false‑positive‑prone.)

### Game‑priority QoS
- **Grouped game‑ports** model with range/CSV support, replacing the flat list.
- **Bitmask‑decomposed `tc` u32 range blocks** + a game‑filter ceiling for accurate
  per‑port prioritisation.
- **Seeded popular mobile‑game defaults** out of the box (MLBB, HoK, CODM), shown as
  a collapsed, view‑proof masked row in the editor.

### Coin‑rate expiry
- New **`wipe_at`** per‑user field (schema **v13**): a coin rate can carry a
  tri‑state expiry that grants a wipe time, swept automatically on expiry, with a
  matching admin UI control.

### Bandwidth / bufferbloat
- **`fq_codel` attached to every per‑client HTB leaf**, fixing bufferbloat under load.

### On‑device sales
- **Reset Sales** on the device, backed by a new `tbl_collections` ledger.

### Admin & captive‑portal UI overhaul
- Broad **UI quality‑of‑life batch** across dashboard, sales, vouchers,
  session policies, portal, insert‑coin and footer, plus a unified **D/H/M** time
  helper and hash‑based tab routing (reload keeps the current page).
- **Branding banner/logo** are now **upload‑only** (URL inputs removed).
- Coin‑rate and game‑priority editors reworked into responsive cards / flat
  1‑row‑per‑entry tables (no horizontal scroll).
- Captive‑portal configuration consolidated out of Settings.

### Diagnostics
- SQLite journal switched to **TRUNCATE** mode, plus an on‑device diagnostics dump
  (`/cgi-bin/debug-logs`) for support.

---

## beta 0.1 — 2026-08-14

Initial public beta.

- Router images for Comfast **CF‑N5 v2** (`zbtlink_zbt-wg3526-16m`) and Ruijie
  **RG‑EW1200G PRO v1.1** (`ruijie_rg-ew1200g-pro-v1.1`), OpenWrt 24.10.3.
- ESP8266 coin‑acceptor node firmware **v1.0** (Wireless + LittleFS images).
- Fully offline PisoWiFi captive portal (coin / voucher / points / free‑time),
  first‑boot self‑init, default LAN `10.0.0.1`, admin `admin`/`admin`.
