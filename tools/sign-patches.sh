#!/bin/sh
# Sign the patch manifest with the offline usign private key.
#
# Usage (from release/):
#   CVFI_PATCH_SIGN_KEY=/secure/path/patches.key sh tools/sign-patches.sh
# If CVFI_PATCH_SIGN_KEY is unset, the script also reads it from the repository
# root .env (local/ignored). It never reads or writes the private key itself.
# The generated patches.json.sig is safe to commit and publish; never commit the
# private key. patch_poll.sh on new firmware verifies this detached signature.
set -eu

MANIFEST="${1:-patches.json}"
USIGN_BIN="${CVFI_USIGN_BIN:-usign}"
SIGNATURE="${MANIFEST}.sig"
KEY="${CVFI_PATCH_SIGN_KEY:-}"

if [ -z "$KEY" ]; then
	ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." 2>/dev/null && pwd)
	if [ -n "$ROOT" ] && [ -f "$ROOT/.env" ]; then
		# .env is operator-controlled and ignored by git. Export its variables so
		# the signing invocation below receives CVFI_PATCH_SIGN_KEY if configured.
		set -a
		. "$ROOT/.env"
		set +a
		KEY="${CVFI_PATCH_SIGN_KEY:-}"
	fi
fi
KEY="${KEY:-keys/patches.key}"

[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST" >&2; exit 2; }
[ -f "$KEY" ] || { echo "private signing key not found: $KEY" >&2; exit 2; }
command -v "$USIGN_BIN" >/dev/null 2>&1 || { echo "usign not found: $USIGN_BIN" >&2; exit 2; }

"$USIGN_BIN" -S -s "$KEY" -m "$MANIFEST" -x "$SIGNATURE"
"$USIGN_BIN" -q -V -p ../firmware/openwrt/files/usr/share/cvfi/patches.pub -m "$MANIFEST" -x "$SIGNATURE"
echo "signed and verified: $SIGNATURE"
