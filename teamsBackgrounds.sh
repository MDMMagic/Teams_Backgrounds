#!/usr/bin/env bash
# =============================================================================
#  teams_backgrounds.sh
#  Prepares images for Microsoft Teams custom backgrounds (macOS / sips)
#
#  For each image in TARGET_DIR it:
#    1. Renames the original to a new GUID filename
#    2. Creates a 280×158 scale-to-cover thumbnail  (<GUID>_thumb.<ext>)
#
#  Ref: https://learn.microsoft.com/en-us/answers/questions/4412157/
#       new-microsoft-teams-for-mac-where-is-the-new-calls
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — edit these before running
# ---------------------------------------------------------------------------
TARGET_DIR=""          # Absolute path to your backgrounds folder
THUMB_W=280            # Thumbnail width  (Teams spec)
THUMB_H=158            # Thumbnail height (Teams spec)
DRY_RUN=0              # 1 = preview only, 0 = make changes

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; GREEN=$'\033[0;32m'
CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

info()    { printf "%b\n"  "${CYAN}[info]${RESET}  $*"; }
ok()      { printf "%b\n"  "${GREEN}[done]${RESET}  $*"; }
warn()    { printf "%b\n"  "${YELLOW}[warn]${RESET}  $*" >&2; }
err()     { printf "%b\n"  "${RED}[error]${RESET} $*" >&2; }
dry()     { printf "%b\n"  "${YELLOW}[dry]${RESET}   $*"; }
header()  { printf "\n%b\n" "${BOLD}$*${RESET}"; }

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
if [[ -z "$TARGET_DIR" ]]; then
    err "TARGET_DIR is not set. Edit the script and try again."
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    err "Directory not found: $TARGET_DIR"
    exit 1
fi

if ! command -v sips &>/dev/null; then
    err "'sips' not found — this script requires macOS."
    exit 1
fi

if ! command -v uuidgen &>/dev/null; then
    err "'uuidgen' not found."
    exit 1
fi

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
cd "$TARGET_DIR"

[[ "$DRY_RUN" -eq 1 ]] && header "=== DRY RUN — no files will be changed ==="

processed=0
skipped=0

while IFS= read -r -d '' path; do
    file="${path#./}"

    # Sanity-check: must be a regular file
    [[ -f "$file" ]] || continue

    ext="${file##*.}"
    # Preserve lowercase extension in output names
    ext_lc="${ext,,}"

    # ------------------------------------------------------------------
    # Read source dimensions
    # ------------------------------------------------------------------
    w="$(sips -g pixelWidth  "$file" 2>/dev/null | awk '/pixelWidth/  {print $2}')"
    h="$(sips -g pixelHeight "$file" 2>/dev/null | awk '/pixelHeight/ {print $2}')"

    if [[ -z "${w:-}" || -z "${h:-}" ]]; then
        warn "Cannot read dimensions, skipping: $file"
        (( skipped++ )) || true
        continue
    fi

    # ------------------------------------------------------------------
    # Generate a collision-free GUID pair
    # ------------------------------------------------------------------
    while :; do
        guid="$(uuidgen | tr '[:lower:]' '[:upper:]')"
        new_original="${guid}.${ext_lc}"
        new_thumb="${guid}_thumb.${ext_lc}"
        [[ ! -e "$new_original" && ! -e "$new_thumb" ]] && break
    done

    info "Processing: ${BOLD}$file${RESET}  (${w}×${h})"

    # ------------------------------------------------------------------
    # Scale-to-cover then centre-crop to exactly THUMB_W × THUMB_H
    # ------------------------------------------------------------------
    read -r newW newH < <(awk \
        -v w="$w" -v h="$h" -v tw="$THUMB_W" -v th="$THUMB_H" '
        BEGIN {
            scaleW = tw / w
            scaleH = th / h
            scale  = (scaleW > scaleH) ? scaleW : scaleH
            nw = int(w * scale + 0.5)
            nh = int(h * scale + 0.5)
            if (nw < tw) nw = tw
            if (nh < th) nh = th
            print nw, nh
        }')

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry "Would rename :  $file  →  $new_original"
        dry "Would create:  $new_thumb  (${newW}×${newH} → ${THUMB_W}×${THUMB_H} crop)"
        (( processed++ )) || true
        continue
    fi

    # Work on a temp file so partial output never replaces the original
    tmp_thumb="$(mktemp).${ext_lc}"

    # Copy source → temp, resize, crop
    cp -- "$file" "$tmp_thumb"
    sips --resampleHeightWidth "$newH" "$newW" "$tmp_thumb" >/dev/null 2>&1
    sips --cropToHeightWidth   "$THUMB_H" "$THUMB_W" "$tmp_thumb" >/dev/null 2>&1

    # Rename original and move thumbnail into place
    mv -n -- "$file"      "$new_original"
    mv -n -- "$tmp_thumb" "$new_thumb"

    ok "  original → $new_original"
    ok "  thumb    → $new_thumb"
    (( processed++ )) || true

done < <(find . -maxdepth 1 -type f \
    \( -iname "*.jpg"  -o -iname "*.jpeg" \
    -o -iname "*.png"  -o -iname "*.heic" \
    -o -iname "*.tif"  -o -iname "*.tiff" \
    -o -iname "*.gif"  -o -iname "*.bmp"  \) \
    ! -iname "*_thumb.*" -print0)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n%b\n" "${BOLD}─────────────────────────────${RESET}"
printf "%b\n"   "  Processed : ${GREEN}${processed}${RESET}"
[[ "$skipped" -gt 0 ]] && \
printf "%b\n"   "  Skipped   : ${YELLOW}${skipped}${RESET}"
[[ "$DRY_RUN" -eq 1 ]] && \
printf "%b\n"   "  ${YELLOW}Dry run — rerun with DRY_RUN=0 to apply.${RESET}"
printf "%b\n\n" "${BOLD}─────────────────────────────${RESET}"
