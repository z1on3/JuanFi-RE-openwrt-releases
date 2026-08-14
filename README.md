# JuanFi Reloaded — Flashable Releases

Prebuilt, ready-to-flash firmware for **JuanFi Reloaded (JuanFi‑RE)** — a
clean‑room, fully‑offline PisoWiFi captive portal (coin / voucher / points /
free‑time) built on stock **OpenWrt**, plus the matching **ESP8266 coin‑acceptor
node** firmware.

> Downloads live on the [**Releases**](../../releases) page. This repository holds
> only the release notes and checksums — the binaries are attached as release
> assets.

---

## What's in the current release

| Component | File | Version |
|---|---|---|
| Router image — Comfast **CF‑N5 v2** | `JuanFi-RE-comfast-cf-n5-v2-24.10.3-beta-0.1.bin` | **beta 0.1** |
| Router image — Ruijie **RG‑EW1200G PRO v1.1** | `JuanFi-RE-ruijie-rg-ew1200g-pro-v1.1-24.10.3-beta-0.1.bin` | **beta 0.1** |
| ESP8266 node — Wireless firmware | `JuanFi-RE-ESP8266-node-Wireless-firmware-v1.0.bin` | **v1.0** |
| ESP8266 node — LittleFS (web UI) image | `JuanFi-RE-ESP8266-node-littlefs-v1.0.bin` | **v1.0** |

Verify downloads against [`SHA256SUMS.txt`](SHA256SUMS.txt):

```sh
sha256sum -c SHA256SUMS.txt
```

---

## Router images

All router images are stock **OpenWrt 24.10.3** (`r28872-daca7c049b`),
`ramips/mt7621` (MediaTek MT7621, `mipsel_24kc`), with the JuanFi‑RE portal + admin
app (PHP 8 + SQLite + nftables captive portal) baked into the rootfs. They
self‑initialise on first boot — no license server, no phone‑home, no encrypted app
blob. Each is ~11 MB and fits the 16 MB flash with headroom.

| Device | OpenWrt profile | Notes |
|---|---|---|
| Comfast **CF‑N5 v2** | `zbtlink_zbt-wg1608-16m` | Not a mainline OpenWrt board; hardware‑compatible with the ZBT **WG1608 (16 MB)** profile, which this image targets. |
| Ruijie **RG‑EW1200G PRO v1.1** | `ruijie_rg-ew1200g-pro-v1.1` | **Officially supported** by OpenWrt (since 24.10.0) — a first‑class device profile. |

### Flashing the router

**There is no custom flashing** — these are standard OpenWrt sysupgrade images. Flash
your device's image exactly as you would any OpenWrt image: via **LuCI → System →
Backup / Flash Firmware → Flash new firmware**, or `sysupgrade` over SSH. Follow the
official OpenWrt guide: <https://openwrt.org/docs/guide-user/installation/generic.flashing>

After reboot the portal is served at the router's LAN IP; the admin panel is at
`/admin/` (first login creates the admin account).

⚠️ **Beta.** Flash at your own risk on hardware you can recover. Each image is only
validated on its listed device.

---

## ESP8266 coin‑acceptor node

The node needs **two** images flashed: the **firmware** and the **LittleFS**
filesystem (the node's web setup UI is served only from LittleFS).

- **Wireless** firmware — node joins the router Wi‑Fi as a station.
- Flash the LittleFS image **before** provisioning; re‑flashing it later wipes the
  saved Wi‑Fi/token/pin config.

### Flashing the node (esptool, ESP‑12E / NodeMCU)

```sh
# firmware
esptool.py --port <PORT> --baud 460800 write_flash 0x0 JuanFi-RE-ESP8266-node-Wireless-firmware-v1.0.bin
# filesystem (LittleFS) — offset is board dependent; 0x200000 for a 4MB/1MB-FS layout
esptool.py --port <PORT> --baud 460800 write_flash 0x200000 JuanFi-RE-ESP8266-node-littlefs-v1.0.bin
```

### Setting up the node after flashing

Once **both** images are flashed, bring the node online from any phone or laptop —
no `curl`, and you never type the router token by hand:

**1. Connect to the node.** In your Wi‑Fi list, join the node's setup network
**`CVFi-Node-Setup`** (open, no password). The "sign in to network" sheet usually
pops automatically; if it doesn't, open `http://192.168.4.1/`. On first access the
node asks you to **create an admin password**, then signs you in to the node's
setup UI.

**2. Put the node on the router Wi‑Fi.** In **Settings → Node settings**, enter your
router's Wi‑Fi SSID/password (and the router's IP/port if it isn't the
`10.0.0.1:80` default), then **Save & reboot**. When it comes back, the
**Dashboard** should show **Router link up** — the node is now on the router
network.

**3. Enroll with an activation code.** The router hands the node its pairing token
through a one‑time code:

1. In the **router admin**, open the **Nodes** page and click **Enroll node** — a
   **6‑digit activation code** appears and the panel waits for the node.
2. On the node's UI, go to **Settings → Pair with router**, type that 6‑digit code,
   and press **Activate**. (The Dashboard must already show **Router link up**.)
3. The node exchanges the code with the router, receives its token, saves it, and
   **reboots paired**. The router's **Nodes** page then shows it online.

The token is fetched automatically and is never displayed on either side. A
wrong/expired/already‑used code shows *"code rejected or expired"* — just generate
a new one on the router and try again.

---

## Building from source

These binaries are built from the [JuanFi Reloaded source](https://openwrt.org/)
with the OpenWrt Image Builder (router) and PlatformIO (`espressif8266`, ESP node).
See the source repo's `firmware/openwrt/IMAGEBUILDER.md` and
`firmware/esp8266-node/platformio.ini`.

---

_JuanFi Reloaded is an independent, clean‑room implementation. Not affiliated with
Comfast, ZBT, or any coin‑acceptor vendor._
