# Changelog

All notable changes to the JuanFi‑RE flashable releases are documented here.

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
