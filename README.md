# dockerfile-app

Demo de um pipeline de build de imagem Docker hardened (Go + Alpine), com scan de vulnerabilidades, verificação CIS, assinatura e SBOM automatizados via GitHub Actions.

## Estrutura

- `Dockerfile` — build multi-stage hardened (versão atual).
- `Dockerfile copy` — versão antiga/não hardened, mantida para comparação.
- `.github/workflows/ci-security.yml` — pipeline de CI (build, scan, sign, SBOM).

## Build e execução local

```bash
docker build -t myapp .
docker run --rm myapp
```

## Pipeline de CI

A cada push/PR para `main` (ou disparo manual), o workflow `ci-security.yml`:

1. Builda a imagem localmente.
2. Roda **Dockle** (CIS Docker Benchmark) — falha em achados `fatal`.
3. Roda **Trivy** (scan de vulnerabilidades CRITICAL) — falha se encontrar CVEs críticas corrigíveis.
4. Roda **Trivy** (scan de segredos CRITICAL) — falha se encontrar segredos expostos.
5. Em push para `main` (não em PR): publica a imagem no GHCR, assina com **Cosign** (keyless) e gera/anexa um **SBOM** (CycloneDX) como attestation assinada.

Relatórios de cada scan (Dockle, Trivy, SBOM) ficam disponíveis como artifacts do workflow, mesmo quando o job falha.

## Boas práticas do Dockerfile

O `Dockerfile` atual segue algumas práticas de hardening que devem ser preservadas em mudanças futuras:

- Build multi-stage (`golang:1.26-alpine3.24` → `alpine:3.24`).
- Binário estático, sem símbolos de debug (`CGO_ENABLED=0`, `-trimpath`, `-ldflags="-s -w"`).
- Usuário não-root dedicado (`appuser`/`appgroup`), sem shell de login.
- Binário com permissões restritas (`chmod 550`) e dono correto.
- Execução como `USER appuser` (nunca root).
- `HEALTHCHECK` e `STOPSIGNAL` definidos explicitamente.
