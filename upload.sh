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

query_jobs="${NIX_CACHE_QUERY_JOBS:-16}"
if [[ ! "$query_jobs" =~ ^[1-9][0-9]{0,2}$ ]] || (( query_jobs > 128 )); then
  echo "NIX_CACHE_QUERY_JOBS must be an integer between 1 and 128." >&2
  exit 1
fi

key_file="$RUNNER_TEMP/nix-cache-private-key"
paths_file="$RUNNER_TEMP/nix-built-paths"
closure_file="$RUNNER_TEMP/nix-built-closure"

cleanup() {
  rm -f "$key_file"
  rm -f "$paths_file"
  rm -f "$closure_file"
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

if (( query_jobs > 1 )); then
  stage_started_at="$SECONDS"
  echo "Resolving the dependency closure of $path_count recorded paths..."
  nix path-info --recursive --stdin < "$paths_file" > "$closure_file"
  closure_count="$(wc -l < "$closure_file" | tr -d ' ')"
  echo "Resolved $closure_count paths including dependencies in $((SECONDS - stage_started_at))s"

  # Nix's S3 metadata query pool is limited to the number of CPU cores.
  # Separate processes share its on-disk narinfo cache, including missing
  # paths. Prefetch disjoint batches so the recursive copy can reuse these
  # checks without uploading overlapping closures in parallel.
  batch_size="$(((closure_count + query_jobs - 1) / query_jobs))"
  if (( batch_size > 32 )); then batch_size=32; fi
  if (( batch_size < 1 )); then batch_size=1; fi
  stage_started_at="$SECONDS"
  echo "Checking S3 cache metadata for $closure_count paths with up to $query_jobs parallel queries..."
  xargs -r -P "$query_jobs" -n "$batch_size" bash -c '
    set -euo pipefail
    upload_url="$1"
    shift
    # --print-invalid permits absent paths. Unlike nix path-info, this
    # only checks the destination, without querying other substituters.
    # The S3 validity check fetches and caches the narinfo metadata.
    nix-store --store "$upload_url" --check-validity --print-invalid "$@" > /dev/null
    echo "Checked cache metadata for $# paths in ${SECONDS}s"
  ' bash "$upload_url" < "$closure_file"
  echo "Checked S3 cache metadata in $((SECONDS - stage_started_at))s"
fi

stage_started_at="$SECONDS"
echo "Copying missing paths and dependencies to S3..."
nix copy --to "$upload_url" --stdin < "$paths_file"
echo "Copied missing paths in $((SECONDS - stage_started_at))s"
echo "Uploaded $path_count Nix paths to $NIX_CACHE_S3_STORE_URL in $((SECONDS - started_at))s"
