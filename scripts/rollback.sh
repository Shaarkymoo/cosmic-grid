#!/usr/bin/env bash
# Revert to the stock (original) COSMIC binaries and release the package holds.
# Run with sudo. Safe to run any time.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
STOCK="$ROOT/stock"
BINS=(cosmic-comp cosmic-workspaces)

for b in "${BINS[@]}"; do
    if [ -f "$STOCK/$b.orig" ]; then
        install -m 755 "$STOCK/$b.orig" "/usr/bin/$b"
        echo "  restored /usr/bin/$b from stock backup"
    else
        echo "  WARN: no stock backup for $b at $STOCK/$b.orig — skipping"
    fi
done

echo "==> Releasing package holds"
apt-mark unhold cosmic-comp cosmic-workspaces || true
apt-mark showhold || true

echo "==> Removing apt pin"
rm -f /etc/apt/preferences.d/99-cosmic-grid.pin
echo "  removed /etc/apt/preferences.d/99-cosmic-grid.pin"

echo
echo "Stock binaries restored. Log out and back in to revert to the default layout."
