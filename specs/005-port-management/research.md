# Research: Port Management for ArgoCD Apps

**Branch**: `005-port-management` | **Date**: 2026-07-29

## Unknowns Resolved

### Port conflict detection in bash

- **Decision**: Use `lsof -i :<port>` for macOS, `ss -tln` as fallback for Linux (already partially implemented in `argocd.sh`)
- **Rationale**: Cross-platform support; `lsof` is available on macOS and Linux; `ss` is preferred on modern Linux
- **Alternatives considered**: `netstat`, `/proc/net/tcp` — less portable or less readable

### Self-signed TLS for k3d/ArgoCD

- **Decision**: One-line openssl command in the bootstrap script; `kubectl create secret tls` for storage
- **Rationale**: Simple, no extra dependencies, no cert-manager needed for local dev
- **Alternatives considered**: cert-manager with self-signed issuer (overkill for local dev), mkcert (extra dependency)

### Traefik port patching — NOT NEEDED

- **Decision**: Do not patch Traefik. Instead, patch argocd-server Service ports from 80/443 to 8081/8443.
- **Rationale**: Traefik stays on its defaults, no conflict, no fragile patching of k3d internals.
- **Alternatives considered**: Patching Traefik off 80/443 (fragile, version-dependent), disabling Traefik entirely (changes k3d behavior too broadly)

### PORT env var pattern for Go apps

- **Decision**: `os.Getenv("PORT", "8090")` in `main.go`; pass env var in Deployment manifest
- **Rationale**: Standard Go 12-factor app pattern; zero new dependencies
- **Alternatives considered**: `flag` package (env var is more k8s-native), hardcoded (current — inflexible)

### Port range for registry fallback

- **Decision**: 50000–50004 (5 ports total)
- **Rationale**: Sufficient headroom for rare collisions without excessive iteration
- **Alternatives considered**: Single fallback (current — fragile), 50-port range (overkill for local dev)
