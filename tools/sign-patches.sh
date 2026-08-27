#!/bin/sh
# Sign the patch manifest with the offline usign private key.
#
# Usage (from release/):
#   CVFI_PATCH_SIGN_KEY=/secure/path/patches.key sh tools/sign-patches.sh
# The generated patches.json.sig is safe to commit and publish; never commit the
# private key. patch_poll.sh on new firmware verifies this detached signature.
set -eu

MANIFEST="${1:-patches.json}"
KEY="${CVFI_PATCH_SIGN_KEY:-keys/patches.key}"
USIGN_BIN="${CVFI_USIGN_BIN:-usign}"
SIGNATURE="${MANIFEST}.sig"

[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST" >&2; exit 2; }
[ -f "$KEY" ] || { echo "private signing key not found: $KEY" >&2; exit 2; }
command -v "$USIGN_BIN" >/dev/null 2>&1 || { echo "usign not found: $USIGN_BIN" >&2; exit 2; }

"$USIGN_BIN" -S -s "$KEY" -m "$MANIFEST" -x "$SIGNATURE"
"$USIGN_BIN" -q -V -p ../firmware/openwrt/files/usr/share/cvfi/patches.pub -m "$MANIFEST" -x "$SIGNATURE"
echo "signed and verified: $SIGNATURE"
