# Report: MinIO image migration to community mirror (2026-06-17)

Branch: `chore/minio-mirror-bump`

## Context (why this was forced)

MinIO stopped publishing free Community Edition images to Docker Hub **and** quay.io
on **2025-10-23**, shifting to a "source-only" distribution model. The
`github.com/minio/minio` repository was **archived on 2026-04-25** (read-only).
Our pinned tag `quay.io/minio/minio:RELEASE.2024-01-01T16-36-33Z` was frozen forever
— no security patches, ~2.5 years stale, vulnerable to **CVE-2025-62506** (restricted
accounts can spawn unrestricted ones, fixed in `RELEASE.2025-10-15`).

This directly threatened invariant #9 (MinIO/S3-compatible storage as default backend).

## Decision

Migrate the **MinIO server** image to the community-maintained mirror **`alpine/minio`**,
pinned to `RELEASE.2025-10-15T17-29-55Z` (the latest security release, which closes
CVE-2025-62506).

**Why `alpine/minio` over `chainguard/minio` (`cgr.dev`):**
- `alpine/minio` keeps the upstream `RELEASE.<date>` tag scheme → drop-in replacement
  (only the `repository` changes), no tag-model adaptation needed.
- `chainguard/minio` uses `latest`/`latest-dev` tag model, which conflicts with our
  version-pinning convention and would require more chart adaptation.
- `alpine/minio` is API-identical to upstream MinIO (built from the same source).

**Trade-off / caveat:** `alpine/minio` is a **community-maintained** image, not an
official MinIO artifact. Trust is placed in the maintainer (Bill WANG / the alpine/minio
Docker Hub namespace). If stronger supply-chain guarantees are needed later, migrate
to `cgr.dev/chainguard/minio` (zero-CVE, non-root by default — also better for PSS
`restricted` / invariant #10).

## What changed (7 files)

MinIO server image `quay.io/minio/minio:RELEASE.2024-*` → `alpine/minio:RELEASE.2025-10-15T17-29-55Z`:

| File | Notes |
|------|-------|
| `charts/spark-3.5/values.yaml` | |
| `charts/spark-3.5/charts/spark-base/values.yaml` | nested spark-base copy |
| `charts/spark-base/values.yaml` | |
| `charts/spark-4.0/values.yaml` | |
| `charts/spark-4.1/values.yaml` | |
| `charts/spark-3.5/spark-infra.yaml` | preset (had a different stale tag `RELEASE.2024-01-16`) |
| `docs/reference/spark-3.5-defaults.md` | generated reference doc |

## ⚠️ Known gap (tracked, not silent)

### GAP-MC: MinIO Client (`mc`) image still on frozen `quay.io/minio/mc:latest`

The MinIO Client is used by bucket-init init-containers and is **hardcoded** in 4
templates (not values-configurable):

- `charts/spark-base/templates/minio.yaml:162`
- `charts/spark-3.5/charts/spark-base/templates/minio.yaml:162`
- `charts/spark-4.0/templates/core/_helpers.tpl:477`
- `charts/spark-4.1/templates/core/_helpers.tpl:477`

`quay.io/minio/mc:latest` is subject to the same freeze as the server image, and
`latest` is additionally non-reproducible. **Deferred** because:
1. `mc` runs only in init jobs (bucket creation), lower blast radius than the server.
2. Making it values-configurable is a small refactor (expose `mc.image` in values),
   better done as its own focused change.
3. `alpine/minio-mc` mirror exists and can be used once the parametrization lands.

Out of scope for this PR. Tracked for a follow-up.

## Verification done

- `helm lint` spark-3.5 / spark-4.0 / spark-4.1 / spark-base → 0 failures each
- `helm template` spark-3.5 with minio enabled → renders `alpine/minio:RELEASE.2025-10-15T17-29-55Z`

## Verification NOT done (requires live cluster)

- Live MinIO deploy + bucket creation (demo not deployed this session)
- CVE-2025-62506 regression test on `alpine/minio:RELEASE.2025-10-15T17-29-55Z`

## References

- Chainguard analysis: https://edu.chainguard.dev/chainguard/chainguard-images/getting-started/minio/
- alpine/minio: https://hub.docker.com/r/alpine/minio/tags
- MinIO archive notice: https://github.com/minio/minio/releases
