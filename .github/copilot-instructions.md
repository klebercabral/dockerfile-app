# Copilot instructions

Guidance for AI assistance in this repository.

## Repository purpose

This is a minimal demo repository for a hardened Docker build pipeline. There is no application source tree to speak of — the "app" is a placeholder Go program generated inline inside the `Dockerfile` itself (`RUN echo 'package main; ...' > main.go`). The real content of this repo is the `Dockerfile` and the CI pipeline that builds, scans, signs, and attests the resulting image.

- `Dockerfile` — current, hardened multi-stage build.
- `Dockerfile copy` — an older/unhardened version kept for reference/comparison. When asked to improve "the Dockerfile," assume `Dockerfile` (not the copy) unless told otherwise.
- `.github/workflows/ci-security.yml` — the CI pipeline (see below).

## Building and running

```bash
docker build -t myapp .
docker run --rm myapp
```

There is no separate test suite, linter, or package manager in this repo — validation happens through the Docker build itself and the CI security tooling described below.

## CI pipeline (`.github/workflows/ci-security.yml`)

Runs on push/PR to `main` and on manual dispatch. Single job `build-scan-sign` does, in order:

1. **Build** the image locally (tagged `<registry>/<repo>:<short-sha>`, lowercased).
2. **Dockle** — CIS Docker Benchmark scan (`--exit-level fatal` fails the build).
3. **Trivy vulnerability scan** — `severity: CRITICAL`, `ignore-unfixed: true`, fails the build on findings.
4. **Trivy secret scan** — `severity: CRITICAL`, fails the build on findings.
5. On `main` pushes only (not PRs): login to GHCR, push `:sha` and `:latest`, sign the image keylessly with **Cosign**, generate a CycloneDX **SBOM** via Trivy, and attach the SBOM as a signed Cosign attestation.

All scan reports (Dockle, Trivy vuln, Trivy secret, SBOM) are uploaded as workflow artifacts even on failure (`if: always()`), so check those artifacts first when the pipeline fails a gate.

Tool versions are pinned via workflow `env` vars (`TRIVY_VERSION`, `DOCKLE_VERSION`, `COSIGN_VERSION`) — bump these deliberately rather than letting them float.

## Dockerfile conventions to preserve

The current `Dockerfile` follows several hardening practices; keep these when editing it:

- Multi-stage build: `golang:1.26-alpine3.24` builder → minimal `alpine:3.24` runtime.
- `apk update && apk upgrade --no-cache` in both stages; runtime stage also clears `/var/cache/apk/*`.
- Static binary build: `CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w"`.
- Dedicated non-root system user/group (`appuser`/`appgroup`) with a locked-down shell (`/sbin/nologin`), created via `-S -D -H`.
- Copied binary is `chown`ed to the non-root user at copy time and `chmod 550` (read+execute, no write).
- Container runs as `USER appuser` (never root).
- `HEALTHCHECK` and `STOPSIGNAL SIGTERM` are explicitly defined.
- `ENTRYPOINT` (not `CMD`) is used to run the binary.

Any change to the Dockerfile should be expected to pass the Dockle/Trivy gates above — e.g. avoid reintroducing root ownership, dropping the non-root user, or adding fixable CRITICAL-severity packages.
