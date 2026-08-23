#!/bin/sh
# Build a CVFi patch tarball + print its patches.json entry (System Update: patches).
#
#   tools/make-patch.sh <id> <target_version> <payload_dir> ["description"]
#
#   <id>             unique patch id, convention "<target>-NNN" e.g. 0.3-001
#   <target_version> the router fw the patch targets, e.g. 0.3-beta (MUST equal
#                    cvfi_fw_version on the routers, or they ignore the patch)
#   <payload_dir>    a dir laid out like the patch archive root:
#                      files/…          mirror of the real fs (files/www/… -> /www/…)
#                      post.sh   (opt)  run after apply (root; trusted)
#                      rollback.sh(opt) run during rollback
#
# Produces  patch-<id>.tar.gz  and prints the ready-to-paste patches.json entry
# (fill in the asset URL after you `gh release upload`). See docs/SYSTEM-UPDATE.md.
set -e

ID="$1"; TARGET="$2"; DIR="$3"; DESC="${4:-}"
[ -n "$ID" ] && [ -n "$TARGET" ] && [ -d "$DIR" ] || {
	echo "usage: make-patch.sh <id> <target_version> <payload_dir> [\"description\"]" >&2; exit 2; }
[ -d "$DIR/files" ] || { echo "error: $DIR/files/ is required (the file payload)" >&2; exit 2; }

OUT="patch-$ID.tar.gz"
# Include files/ plus any hooks that exist. Deterministic-ish; the sha is what matters.
SET="files"
[ -f "$DIR/post.sh" ] && SET="$SET post.sh"
[ -f "$DIR/rollback.sh" ] && SET="$SET rollback.sh"

( cd "$DIR" && tar czf - $SET ) > "$OUT"
SHA=$(sha256sum "$OUT" | awk '{print $1}')

echo "built: $OUT ($(wc -c < "$OUT") bytes)" >&2
echo "sha256: $SHA" >&2
echo "" >&2
echo "1) gh release upload patches $OUT --repo z1on3/JuanFi-RE-openwrt-releases" >&2
echo "2) add this entry to patches.json (bump seq), set the url, then git push:" >&2
echo "" >&2
cat <<EOF
    {
      "id": "$ID",
      "seq": <NEXT_SEQ>,
      "target_version": "$TARGET",
      "desc": "$DESC",
      "url": "https://github.com/z1on3/JuanFi-RE-openwrt-releases/releases/download/patches/$OUT",
      "sha256": "$SHA",
      "revoked": false
    }
EOF
