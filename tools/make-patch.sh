#!/bin/sh
# Build a CVFi patch tarball + print its patches.json entry (System Update: patches).
#
#   tools/make-patch.sh [--baseline-dir <files-dir> | --baseline-ref <git-ref>]
#                       [--manifest <patches.json>] [--allow-overwrite <file>]...
#                       <id> <target_version> <payload_dir> ["description"]
#
#   <id>             unique patch id, convention "<target>-NNN" e.g. 0.3-001
#   <target_version> the router fw the patch targets, e.g. 0.3-beta (MUST equal
#                    cvfi_fw_version on the routers, or they ignore the patch)
#   <payload_dir>    a dir laid out like the patch archive root:
#                      files/…          mirror of the real fs (files/www/… -> /www/…)
#                      post.sh   (opt)  run after apply (root; trusted)
#                      rollback.sh(opt) run during rollback
#
# A payload file replaces the live file. Before packing, this script compares every
# overlapping file with the accumulated earlier patch state for the same firmware
# version. It blocks a new file that drops non-conflicting earlier changes.
# Supply the original image files with --baseline-dir, or their git commit with
# --baseline-ref. --allow-overwrite is a deliberate, per-file escape hatch.
set -e

BASE_DIR="${CVFI_PATCH_BASELINE_DIR:-}"
BASE_REF="${CVFI_PATCH_BASELINE_REF:-}"
MANIFEST="${CVFI_PATCH_MANIFEST:-patches.json}"
ALLOW=""
while [ $# -gt 0 ]; do
	case "$1" in
		--baseline-dir) BASE_DIR="$2"; BASE_REF=""; shift 2 ;;
		--baseline-ref) BASE_REF="$2"; BASE_DIR=""; shift 2 ;;
		--manifest) MANIFEST="$2"; shift 2 ;;
		--allow-overwrite) case "$2" in files/*) X="$2" ;; *) X="files/$2" ;; esac; ALLOW="$ALLOW $X"; shift 2 ;;
		--) shift; break ;;
		-*) echo "error: unknown option: $1" >&2; exit 2 ;;
		*) break ;;
	esac
done
ID="$1"; TARGET="$2"; DIR="$3"; DESC="${4:-}"
[ -n "$ID" ] && [ -n "$TARGET" ] && [ -d "$DIR" ] || {
	echo "usage: make-patch.sh [options] <id> <target_version> <payload_dir> [\"description\"]" >&2; exit 2; }
[ -d "$DIR/files" ] || { echo "error: $DIR/files/ is required (the file payload)" >&2; exit 2; }
[ -f "$MANIFEST" ] || { echo "error: manifest not found: $MANIFEST" >&2; exit 2; }
[ -z "$BASE_DIR" ] || [ -d "$BASE_DIR" ] || { echo "error: baseline dir not found: $BASE_DIR" >&2; exit 2; }
[ -z "$BASE_REF" ] || git rev-parse --verify -q "$BASE_REF^{commit}" >/dev/null || { echo "error: baseline git ref is not a commit: $BASE_REF" >&2; exit 2; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/cvfi-patch.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
# Git for Windows may place Windows sort.exe ahead of GNU sort; that executable
# does not support the field options used below.
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*) PATH="/usr/bin:$PATH" ;; esac
# Read prior entries for the same version (works with compact or pretty JSON).
PRIOR=$(awk -v target="$TARGET" 'BEGIN { RS="}" } function val(s,k,v) { v=s; sub(".*\\\"" k "\\\"[[:space:]]*:[[:space:]]*", "", v); sub("[,}].*", "", v); gsub(/^[[:space:]\"]+|[[:space:]\"]+$/, "", v); return v } { if (val($0,"target_version") != target || val($0,"revoked") == "true") next; seq=val($0,"seq"); url=val($0,"url"); if (seq ~ /^[0-9]+$/ && url != "") { sub(/^.*\//,"",url); print seq "|" url } }' "$MANIFEST" | sort -n -t'|' -k1,1)
STATE="$TMP/prior-state"; mkdir -p "$STATE"; HAVE_PRIOR=0
if [ -n "$PRIOR" ]; then
	for ENTRY in $PRIOR; do
		ARCHIVE=${ENTRY#*|}
		[ "$ARCHIVE" = "patch-$ID.tar.gz" ] && continue
		[ -f "$ARCHIVE" ] || { echo "error: prior patch archive missing locally: $ARCHIVE (from $MANIFEST)" >&2; exit 2; }
		tar xzf "$ARCHIVE" -C "$STATE"; HAVE_PRIOR=1
	done
fi
if [ "$HAVE_PRIOR" -eq 1 ]; then
	( cd "$DIR" && find files -type f -print | LC_ALL=C sort ) > "$TMP/payload-files"
	while IFS= read -r PATH_IN_ARCHIVE; do
		PRIOR_FILE="$STATE/$PATH_IN_ARCHIVE"; NEW_FILE="$DIR/$PATH_IN_ARCHIVE"
		[ -f "$PRIOR_FILE" ] || continue
		if printf '%s' "$ALLOW" | tr ' ' '\n' | grep -Fqx "$PATH_IN_ARCHIVE"; then echo "preflight: allowed intentional overwrite: $PATH_IN_ARCHIVE" >&2; continue; fi
		BASE="$TMP/base"; rm -f "$BASE"; REL=${PATH_IN_ARCHIVE#files/}
		if [ -n "$BASE_DIR" ] && [ -f "$BASE_DIR/$REL" ]; then cp "$BASE_DIR/$REL" "$BASE"
		elif [ -n "$BASE_REF" ] && git cat-file -e "$BASE_REF:firmware/openwrt/files/$REL" 2>/dev/null; then git show "$BASE_REF:firmware/openwrt/files/$REL" > "$BASE"; fi
		if [ ! -f "$BASE" ]; then
			if ! cmp -s "$PRIOR_FILE" "$NEW_FILE"; then echo "error: $PATH_IN_ARCHIVE replaces a prior patch file absent from the baseline." >&2; echo "       Review it and pass --allow-overwrite $PATH_IN_ARCHIVE, or provide the correct baseline." >&2; exit 1; fi
			continue
		fi
		MERGED="$TMP/merged"
		if git merge-file -p "$PRIOR_FILE" "$BASE" "$NEW_FILE" > "$MERGED"; then
			if ! cmp -s "$MERGED" "$NEW_FILE"; then echo "error: $PATH_IN_ARCHIVE would discard non-conflicting changes from an earlier patch." >&2; echo "       Rebuild from the cumulative patched state, or pass --allow-overwrite $PATH_IN_ARCHIVE after review." >&2; exit 1; fi
		else
			echo "error: $PATH_IN_ARCHIVE conflicts with an earlier patch; its merged state needs review." >&2; echo "       Rebuild from the cumulative patched file, or pass --allow-overwrite $PATH_IN_ARCHIVE after review." >&2; exit 1
		fi
	done < "$TMP/payload-files"
	echo "preflight: prior patch overlay preserved" >&2
fi

# Auto-stamp the admin cache-busters (?v=) from each asset's content hash if this
# payload carries the admin bundle, so a patched admin.js/admin.css can never be
# served stale from a browser cache (no manual ?v= bump). Mirrors the image build's
# firmware/openwrt/tools/stamp-cachebust.sh.
_html="$DIR/files/www/admin/index.html"
if [ -f "$_html" ]; then
	for _a in admin.js admin.css; do
		_f="$DIR/files/www/admin/assets/$_a"
		[ -f "$_f" ] || continue
		_h=$(sha256sum "$_f" 2>/dev/null | cut -c1-10)
		[ -n "$_h" ] || continue
		sed -i "s#\(assets/$_a\)?v=[0-9A-Za-z]*#\1?v=$_h#g" "$_html"
		echo "stamp-cachebust: $_a?v=$_h" >&2
	done
fi

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
