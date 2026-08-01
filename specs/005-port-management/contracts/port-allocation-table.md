# Contract: Port Allocation Table

**Location**: Header comment block in `argocd.sh`

## Format

```text
# Port Allocation Table
# Service         | Host   | Cluster | Service | Container | TLS | Defined In
# ----------------|--------|---------|---------|-----------|-----|-----------
# ArgoCD HTTP     | 8081   | 8081    | 8081    | 8080      | no  | argocd.sh (k3d --port, svc patch)
# ArgoCD HTTPS    | 8443   | 8443    | 8443    | 443       | yes | argocd.sh (k3d --port, svc patch)
# Go Server       | 8090   | 8090    | 8090    | 8090      | no  | argocd.sh (k3d --port), deployment.yaml
# Registry        | 50000  | 5000    | n/a     | n/a       | no  | argocd.sh (k3d registry create)

# Reserved ranges
# Host ports:    8081, 8443, 8090     (apps)
# Host ports:    50000-50004           (registry fallback)

# Note: Traefik keeps its default 80/443 — no patching needed
```

## Validation Rules

1. Every new service must be added to this table before creating port mappings
2. Host ports must not overlap with existing entries
3. Cluster ports must not overlap with existing entries
4. Registry port is always 5000 internally (Docker convention), host port varies
