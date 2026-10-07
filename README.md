# Nix S3 cache action

Composite GitHub Action for recording Nix build output paths and uploading them
to an S3-backed binary cache.

## Usage

```yaml
- name: Enable Nix remote cache path recorder
  uses: typeable/nix-s3-cache-action@v1
  with:
    operation: enable-recorder

- name: Upload built Nix paths to S3 cache
  if: always()
  uses: typeable/nix-s3-cache-action@v1
  with:
    operation: upload
    aws-role-to-assume: ${{ secrets.AWS_NIX_CACHE_IAM_ROLE }}
    aws-region: us-east-1
    role-duration-seconds: 21600
    cache-private-key: ${{ secrets.NIX_CACHE_PRIVATE_KEY }}
    cache-s3-store-url: ${{ vars.NIX_CACHE_S3_STORE_URL }}
```

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `operation` | yes | | Operation to run: `enable-recorder` or `upload`. |
| `aws-role-to-assume` | no | | AWS IAM role to assume before uploading Nix paths. |
| `aws-region` | no | `us-east-1` | AWS region for the Nix cache upload role. |
| `role-duration-seconds` | no | `21600` | AWS role duration for the Nix cache upload role. |
| `cache-private-key` | no | | Private signing key for the Nix binary cache. |
| `cache-s3-store-url` | no | | Nix S3 store URL used as the `nix copy` destination. |
| `cache-query-jobs` | no | `16` | Parallel cache metadata queries, from `1` to `128`. Set to `1` to disable metadata prefetch and use Nix's native concurrency. |

Before uploading, the action resolves the recorded paths' full dependency
closure and checks S3 metadata in parallel. These checks populate Nix's shared
on-disk narinfo cache, so the subsequent `nix copy` can reuse the results.
Missing paths are expected; other query errors fail the action. The copy remains
recursive and uploads dependencies before their dependents.

This helps when the runner has few CPU cores and S3 request latency dominates:
Nix 2.24 limits its native S3 metadata query pool to the number of CPU cores.
`parallel-compression=true` only parallelizes compression, not these queries.
The action logs closure resolution, metadata query batches, and copy durations.

To tune the metadata concurrency, add `cache-query-jobs: "32"` to the upload
step's `with` block. More workers use more memory and S3 connections; they do
not change the number of concurrent NAR uploads within `nix copy`.
