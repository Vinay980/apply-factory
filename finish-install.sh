#!/usr/bin/env bash
# finish-install.sh — smart installer for career-ops-extension
#
# Run this from ANYWHERE — it figures out where things should go.
#
# It handles the common case where you extracted the zip inside
# career-ops/extensions/ (which is what you did):
#
#     career-ops/
#     └── extensions/
#         └── career-ops-extension/     ← this script's parent
#             ├── modes/
#             ├── extensions/apply-factory/
#             └── finish-install.sh     ← you're here
#
# It moves modes/*.md up to career-ops/modes/, moves apply-factory/ up
# to career-ops/extensions/apply-factory/, and cleans up the staging folder.

set -euo pipefail

# Where this script lives
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Walk up from the script location looking for career-ops root
# (identified by AGENTS.md + modes/ directory, and NOT being the staging folder itself)
CAREEROPS_DIR=""
D="$(dirname "$SCRIPT_DIR")"
while [[ "$D" != "/" && "$D" != "." ]]; do
    if [[ -f "$D/AGENTS.md" && -d "$D/modes" && "$D" != "$SCRIPT_DIR" ]]; then
        CAREEROPS_DIR="$D"
        break
    fi
    D="$(dirname "$D")"
done

if [[ -z "$CAREEROPS_DIR" ]]; then
    echo "ERROR: couldn't auto-detect career-ops root."
    echo "  This script must be inside a career-ops checkout."
    echo "  Expected to find AGENTS.md + modes/ somewhere above:"
    echo "  $SCRIPT_DIR"
    exit 1
fi

echo "==> career-ops root:    $CAREEROPS_DIR"
echo "==> staging folder:     $SCRIPT_DIR"
echo ""

# Check for mode-file collisions before moving anything
NEW_MODES=(fill.md learn.md linkedin.md linkedin-easy.md kb-review.md briefing.md)
CONFLICTS=()
for f in "${NEW_MODES[@]}"; do
    if [[ -e "$CAREEROPS_DIR/modes/$f" ]]; then
        CONFLICTS+=("$f")
    fi
done
if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
    echo "ERROR: these mode files already exist in $CAREEROPS_DIR/modes/:"
    printf '  %s\n' "${CONFLICTS[@]}"
    echo ""
    echo "  Either delete them (if leftovers) or rename them, then rerun."
    exit 1
fi

echo "==> Moving mode files to $CAREEROPS_DIR/modes/"
for f in "${NEW_MODES[@]}"; do
    if [[ -f "$SCRIPT_DIR/modes/$f" ]]; then
        mv "$SCRIPT_DIR/modes/$f" "$CAREEROPS_DIR/modes/"
        echo "    + modes/$f"
    fi
done

# Note about the user's own Full_stack folder if present
if [[ -d "$SCRIPT_DIR/modes/Full_stack" ]]; then
    echo ""
    echo "==> Found modes/Full_stack/ in the staging folder (not from this extension)."
    echo "    Leaving it where it is — move it manually if you want it under"
    echo "    $CAREEROPS_DIR/modes/Full_stack/"
fi

echo ""
echo "==> Moving extensions/apply-factory to $CAREEROPS_DIR/extensions/"
mkdir -p "$CAREEROPS_DIR/extensions"
if [[ -e "$CAREEROPS_DIR/extensions/apply-factory" ]]; then
    BAK="$CAREEROPS_DIR/extensions/apply-factory.bak.$(date +%s)"
    echo "    Existing apply-factory found — backing up to $BAK"
    mv "$CAREEROPS_DIR/extensions/apply-factory" "$BAK"
fi
mv "$SCRIPT_DIR/extensions/apply-factory" "$CAREEROPS_DIR/extensions/"

# Clean up any stray brace-artifact directories from earlier packaging bugs
rm -rf "$CAREEROPS_DIR/extensions/apply-factory/{lib,learner,prompts,artifacts,snapshots}" 2>/dev/null || true

echo ""
echo "==> Installing Python deps..."
INSTALL_OK=0
for cmd in pip pip3; do
    if command -v "$cmd" >/dev/null 2>&1; then
        # Try the common installation modes in order of preference
        if "$cmd" install --quiet pyyaml 2>/dev/null \
            || "$cmd" install --user --quiet pyyaml 2>/dev/null \
            || "$cmd" install --break-system-packages --quiet pyyaml 2>/dev/null; then
            INSTALL_OK=1
            break
        fi
    fi
done
if [[ "$INSTALL_OK" -ne 1 ]]; then
    echo "    WARN: couldn't install pyyaml automatically."
    echo "    Install it manually before running orchestrator.py, e.g.:"
    echo "      pip install --user pyyaml"
    echo "      pip install --break-system-packages pyyaml"
    echo "      python3 -m venv .venv && .venv/bin/pip install pyyaml"
fi

echo ""
echo "==> Initializing KB..."
cd "$CAREEROPS_DIR/extensions/apply-factory"
if ! python3 orchestrator.py init 2>&1; then
    echo "    KB init failed — likely pyyaml missing. Fix pyyaml then re-run:"
    echo "      cd $CAREEROPS_DIR/extensions/apply-factory && python3 orchestrator.py init"
fi

echo ""
echo "==> Cleaning up staging folder..."
# Only delete the staging folder if it's now empty of stuff we care about
# (should just have README.md, install.sh, and this script left over)
cd "$SCRIPT_DIR"
if [[ -d modes ]] && [[ -z "$(ls -A modes 2>/dev/null | grep -v Full_stack)" ]]; then
    rmdir modes 2>/dev/null || true
fi
if [[ -d extensions ]] && [[ -z "$(ls -A extensions 2>/dev/null)" ]]; then
    rmdir extensions 2>/dev/null || true
fi

# Check what's left
REMAINING="$(find "$SCRIPT_DIR" -mindepth 1 -maxdepth 2 -not -name '.*' 2>/dev/null | wc -l)"
if [[ "$REMAINING" -le 3 ]]; then
    echo "    Staging folder has only README.md / install.sh / this script left."
    echo "    Safe to remove: rm -rf \"$SCRIPT_DIR\""
else
    echo "    Some files remain in $SCRIPT_DIR — review before deleting:"
    ls -la "$SCRIPT_DIR"
fi

echo ""
echo "======================================"
echo "  Done. Verify with:"
echo "    cd $CAREEROPS_DIR/extensions/apply-factory"
echo "    python3 orchestrator.py briefing"
echo ""
echo "  Then in your agent (opencode/kimi/claude) launched from $CAREEROPS_DIR:"
echo "    /career-ops briefing"
echo "======================================"
