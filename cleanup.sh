set -euo pipefail

rm -f "$RUNNER_TEMP/nix-cache-private-key"
rm -f "$RUNNER_TEMP/nix-built-paths"
rm -f "$RUNNER_TEMP/nix-built-closure"
rm -f /tmp/nix-record-built-paths
rm -f /tmp/nix-built-paths
rm -f /tmp/nix-built-paths.lock
