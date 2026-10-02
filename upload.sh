set -euo pipefail

if [ ! -s /tmp/nix-built-paths ]; then
  echo "No Nix paths were recorded for upload."
  exit 0
fi

if [ -z "${NIX_CACHE_PRIVATE_KEY:-}" ]; then
  echo "NIX_CACHE_PRIVATE_KEY is not set." >&2
  exit 1
fi

if [ -z "${NIX_CACHE_S3_STORE_URL:-}" ]; then
  echo "NIX_CACHE_S3_STORE_URL is not set." >&2
  exit 1
fi

key_file="$RUNNER_TEMP/nix-cache-private-key"
paths_file="$RUNNER_TEMP/nix-built-paths"

cleanup() {
  rm -f "$key_file"
  rm -f "$paths_file"
}
trap cleanup EXIT

printf '%s\n' "$NIX_CACHE_PRIVATE_KEY" > "$key_file"
chmod 0600 "$key_file"
sort -u /tmp/nix-built-paths > "$paths_file"

if [ ! -s "$paths_file" ]; then
  echo "No Nix paths were recorded for upload."
  exit 0
fi

upload_url="$NIX_CACHE_S3_STORE_URL"
append_store_param() {
  local key="$1"
  local value="$2"
  case "$upload_url" in
    *\?"$key"=*|*\&"$key"=*) return 0 ;;
  esac
  case "$upload_url" in
    *\?*) upload_url="$upload_url&$key=$value" ;;
    *) upload_url="$upload_url?$key=$value" ;;
  esac
}

append_store_param secret-key "$key_file"
append_store_param compression zstd
append_store_param compression-level 1
append_store_param parallel-compression true

path_count="$(wc -l < "$paths_file" | tr -d ' ')"
echo "Uploading $path_count Nix paths to $NIX_CACHE_S3_STORE_URL"
started_at="$SECONDS"
xargs -r nix copy --to "$upload_url" < "$paths_file"
echo "Uploaded $path_count Nix paths to $NIX_CACHE_S3_STORE_URL in $((SECONDS - started_at))s"

