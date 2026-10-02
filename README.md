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
