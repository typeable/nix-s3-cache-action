set -euo pipefail

tee /tmp/nix-record-built-paths > /dev/null <<'EOF'
#!/bin/sh
set -eu
set -f

if [ -n "${OUT_PATHS:-}" ]; then
  touch /tmp/nix-built-paths /tmp/nix-built-paths.lock
  (
    flock 9
    printf '%s\n' $OUT_PATHS >> /tmp/nix-built-paths
  ) 9>/tmp/nix-built-paths.lock
fi
EOF

chmod +x /tmp/nix-record-built-paths
touch /tmp/nix-built-paths /tmp/nix-built-paths.lock
chmod 0666 /tmp/nix-built-paths /tmp/nix-built-paths.lock
echo "post-build-hook = /tmp/nix-record-built-paths" | sudo tee -a /etc/nix/nix.conf
nix show-config | grep -F "/tmp/nix-record-built-paths"

