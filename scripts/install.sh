#!/usr/bin/env bash
# Install patched binaries: back up stock, replace, hold packages.
# Run with sudo. Reversible via ./scripts/rollback.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
STOCK="$ROOT/stock"
BINS=(cosmic-comp cosmic-workspaces)

echo "==> Backing up stock binaries to $STOCK"
for b in "${BINS[@]}"; do
    if [ ! -f "$STOCK/$b.orig" ] && [ -f "/usr/bin/$b" ]; then
        cp -v "/usr/bin/$b" "$STOCK/$b.orig"
    elif [ -f "$STOCK/$b.orig" ]; then
        echo "  (backup already exists: $STOCK/$b.orig)"
    fi
    if [ ! -f "$ROOT/$b/target/release/$b" ]; then
        echo "ERROR: missing build artifact: $ROOT/$b/target/release/$b (run ./scripts/build.sh first)" >&2
        exit 1
    fi
done

echo "==> Installing patched binaries"
for b in "${BINS[@]}"; do
    install -m 755 "$ROOT/$b/target/release/$b" "/usr/bin/$b"
    echo "  installed /usr/bin/$b"
done

echo "==> Holding packages against updates"
apt-mark hold cosmic-comp cosmic-workspaces
apt-mark showhold

echo
echo "Installed. Log out and back in (or reboot) to activate the grid."
echo "Roll back any time with:  sudo ./scripts/rollback.sh"
