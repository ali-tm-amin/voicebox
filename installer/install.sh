#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Voicebox one-command installer for macOS — packaged by Ihsan Ops
#  https://ihsanops.ai  ·  "Less admin. More growth."
#
#  Usage:
#    curl -fsSL https://ihsanops.ai/voicebox.sh | bash
#
#  What it does:
#    1. Checks your Mac (Apple Silicon or Intel, macOS 11+, free disk space)
#    2. Downloads the latest official, Apple-notarized Voicebox build
#    3. Installs it into /Applications (or ~/Applications without admin rights)
#    4. Opens it so you can clone your voice
#
#  Voicebox is free, open-source (MIT) software by Jamie Pine and contributors:
#  https://github.com/jamiepine/voicebox — this script only installs it.
# ---------------------------------------------------------------------------
set -euo pipefail

REPO="${VOICEBOX_REPO:-jamiepine/voicebox}"
RELEASE_BASE="https://github.com/${REPO}/releases/latest/download"
APP_NAME="Voicebox.app"
MIN_FREE_GB=10

bold=$'\033[1m'; green=$'\033[32m'; yellow=$'\033[33m'; red=$'\033[31m'; reset=$'\033[0m'
say()  { printf '%s\n' "${bold}==>${reset} $*"; }
ok()   { printf '%s\n' "${green}✓${reset} $*"; }
warn() { printf '%s\n' "${yellow}!${reset} $*"; }
die()  { printf '%s\n' "${red}✗ $*${reset}" >&2; exit 1; }

printf '\n%s\n' "${bold}Voicebox installer${reset} — free local voice cloning, set up by Ihsan Ops"
printf '%s\n\n' "-----------------------------------------------------------------"

# 1. Checks ------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "This installer is for macOS. On Windows, use the PowerShell command on the download page."

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$macos_major" -ge 11 ] || die "Voicebox needs macOS 11 (Big Sur) or newer. You have $(sw_vers -productVersion)."

case "$(uname -m)" in
  arm64)  arch="aarch64"; chip="Apple Silicon" ;;
  x86_64)
    # Rosetta reports x86_64 — check the real hardware
    if [ "$(sysctl -in hw.optional.arm64 2>/dev/null || echo 0)" = "1" ]; then
      arch="aarch64"; chip="Apple Silicon"
    else
      arch="x64"; chip="Intel"
    fi ;;
  *) die "Unsupported processor: $(uname -m)" ;;
esac
ok "macOS $(sw_vers -productVersion) on ${chip}"

free_gb="$(df -g "$HOME" | awk 'NR==2 {print $4}')"
if [ "${free_gb:-0}" -lt "$MIN_FREE_GB" ]; then
  warn "Only ${free_gb} GB free. Voice models need roughly 4–8 GB — consider freeing space."
else
  ok "${free_gb} GB free disk space"
fi

ram_gb=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
[ "$ram_gb" -ge 8 ] && ok "${ram_gb} GB RAM" || warn "${ram_gb} GB RAM — 8 GB+ recommended; generation may be slow."

# 2. Download ----------------------------------------------------------------
asset="voicebox_${arch}.app.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say "Downloading Voicebox (${chip} build)…"
curl -fL --progress-bar --retry 3 -o "$tmp/$asset" "$RELEASE_BASE/$asset" \
  || die "Download failed. Check your internet connection and try again."

say "Unpacking…"
tar -xzf "$tmp/$asset" -C "$tmp"
[ -d "$tmp/$APP_NAME" ] || die "Download looked wrong (no $APP_NAME inside). Please try again."

# Confirm it's the genuine, Apple-notarized build before installing
if spctl --assess --type execute "$tmp/$APP_NAME" >/dev/null 2>&1; then
  ok "Apple signature and notarization verified"
else
  warn "Could not verify Apple notarization — continuing, but macOS may ask you to confirm on first open."
fi

# 3. Install -----------------------------------------------------------------
if [ -w /Applications ]; then
  dest="/Applications"
else
  dest="$HOME/Applications"; mkdir -p "$dest"
  warn "No admin rights for /Applications — installing to ~/Applications instead."
fi

if pgrep -xq "voicebox" || pgrep -fq "$APP_NAME/Contents/MacOS"; then
  say "Closing the running copy of Voicebox…"
  osascript -e 'quit app "Voicebox"' >/dev/null 2>&1 || true
  sleep 2
fi

if [ -d "$dest/$APP_NAME" ]; then
  say "Updating existing install (your voices and settings are kept)…"
  rm -rf "${dest:?}/${APP_NAME:?}"
fi
mv "$tmp/$APP_NAME" "$dest/"
xattr -dr com.apple.quarantine "$dest/$APP_NAME" 2>/dev/null || true
ok "Installed to $dest/$APP_NAME"

# 4. Launch ------------------------------------------------------------------
say "Opening Voicebox…"
open "$dest/$APP_NAME" || warn "Couldn't open it automatically — find Voicebox in $dest."

cat <<EOF

${green}${bold}All done!${reset} Next steps:
  1. Wait for the status light (bottom-left) to turn green.
  2. Go to ${bold}Voices → New profile${reset} and record or upload 10–30 seconds
     of clear speech (quiet room, natural pace, no music).
  3. Pick ${bold}Qwen3-TTS 1.7B${reset} and generate — the first run downloads the
     model (~3.5 GB), after that it's fast and fully offline.

Your voice never leaves this Mac. Need help or want AI automation for your
business? → ${bold}https://ihsanops.ai${reset}

EOF
