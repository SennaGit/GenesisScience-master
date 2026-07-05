#!/usr/bin/env bash
# Fetch the pinned aether-synth-skills pack into runtime/skills/external/aether-synth-skills/
# (git-ignored; bundled into the installer as a Tauri resource).
# Runs locally and in CI so the skills never live in this repo's git history.
set -euo pipefail

AETHER_SYNTH_SKILLS_COMMIT="${AETHER_SYNTH_SKILLS_COMMIT:-8fa2ab0523082c135598909b227ed8feb48263ad}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$ROOT/runtime/skills/external/aether-synth-skills"

URL="https://github.com/aether-synth/aether-synth-skills/archive/${AETHER_SYNTH_SKILLS_COMMIT}.tar.gz"
TMP="$(mktemp -d)"
echo "Downloading $URL"
curl -fsSL "$URL" -o "$TMP/skills.tar.gz"
tar -xzf "$TMP/skills.tar.gz" -C "$TMP"

SRC="$(find "$TMP" -maxdepth 1 -type d -name 'aether-synth-skills-*' | head -1)"
[ -d "$SRC/skills" ] || { echo "No skills/ directory in archive" >&2; exit 1; }

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cp -R "$SRC/skills/." "$OUT_DIR/"
echo "$AETHER_SYNTH_SKILLS_COMMIT" > "$OUT_DIR/.commit"
rm -rf "$TMP"

echo "Placed aether-synth-skills@${AETHER_SYNTH_SKILLS_COMMIT:0:7} in $OUT_DIR:"
ls "$OUT_DIR"
