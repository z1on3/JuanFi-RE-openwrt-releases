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
| Router image (Comfast **CF‑N5 v2**) | `JuanFi-RE-comfast-cf-n5-v2-24.10.3-beta-0.1.bin` | **beta 0.1** |
| ESP8266 node — Wireless firmware | `JuanFi-RE-ESP8266-node-Wireless-firmware-v1.0.bin` | **v1.0** |
| ESP8266 node — LAN firmware | `JuanFi-RE-ESP8266-node-LAN-firmware-v1.0.bin` | **v1.0** |
| ESP8266 node — LittleFS (web UI) image | `JuanFi-RE-ESP8266-node-littlefs-v1.0.bin` | **v1.0** |

Verify downloads against [`SHA256SUMS.txt`](SHA256SUMS.txt):

```sh
sha256sum -c SHA256SUMS.txt
```

---

## Router image — Comfast CF‑N5 v2

- **Base:** stock **OpenWrt 24.10.3** (`r28872-daca7c049b`), target `ramips/mt7621`.
- **Device profile:** `zbtlink_zbt-wg1608-16m`. The CF‑N5 v2 is not a mainline
  OpenWrt board; it is hardware‑compatible with the ZBT **WG1608 (16 MB)** profile,
  which is what this image targets.
- The JuanFi‑RE portal + admin app (PHP 8 + SQLite + nftables captive portal) is
  baked into the rootfs and initialises itself on first boot. No license server,
  no phone‑home, no encrypted app blob.

### Flashing the router

1. Copy the image to the router (SSH/SCP) into `/tmp`.
2. Flash with sysupgrade (**`-n` wipes config for a clean first boot — recommended**):
   ```sh
   sysupgrade -n /tmp/JuanFi-RE-comfast-cf-n5-v2-24.10.3-beta-0.1.bin
   ```
   - Upgrading **from an older swconfig OpenWrt** may require `-F` (force) because
     this image is DSA‑based (`compat 1.1`).
3. After reboot the portal is served at the router's LAN IP; the admin panel is at
   `/admin/` (first login creates the admin account).

> **Recovery:** the MT7621 has a U‑Boot web recovery — hold **reset** while powering
> on, set your PC to `192.168.1.x`, and flash via the recovery page at `192.168.1.1`.

⚠️ **Beta.** Flash at your own risk on hardware you can recover. Only tested on the
CF‑N5 v2 / WG1608‑16m combination.

---

## ESP8266 coin‑acceptor node

The node needs **two** images flashed: the **firmware** and the **LittleFS**
filesystem (the node's web setup UI is served only from LittleFS).

- **Wireless** firmware — node joins the router Wi‑Fi as a station (default).
- **LAN** firmware — same, with the provisioning role marked as wired/LAN.
- Flash the LittleFS image **before** provisioning; re‑flashing it later wipes the
  saved Wi‑Fi/token/pin config.

### Flashing the node (esptool, ESP‑12E / NodeMCU)

```sh
# firmware (choose Wireless or LAN)
esptool.py --port <PORT> --baud 460800 write_flash 0x0 JuanFi-RE-ESP8266-node-Wireless-firmware-v1.0.bin
# filesystem (LittleFS) — offset is board dependent; 0x200000 for a 4MB/1MB-FS layout
esptool.py --port <PORT> --baud 460800 write_flash 0x200000 JuanFi-RE-ESP8266-node-littlefs-v1.0.bin
```

Then open the node's setup page (its AP or LAN IP) to provision Wi‑Fi + the
router pairing token.

---

## Building from source

These binaries are built from the [JuanFi Reloaded source](https://openwrt.org/)
with the OpenWrt Image Builder (router) and PlatformIO (`espressif8266`, ESP node).
See the source repo's `firmware/openwrt/IMAGEBUILDER.md` and
`firmware/esp8266-node/platformio.ini`.

---

_JuanFi Reloaded is an independent, clean‑room implementation. Not affiliated with
Comfast, ZBT, or any coin‑acceptor vendor._
