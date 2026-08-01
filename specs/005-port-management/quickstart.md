# Quickstart: Port Management for ArgoCD Apps

## What this covers

Best practices for managing application ports in the ArgoCD/k3d bootstrap environment — avoiding conflicts, adding HTTPS, and making ports configurable.

## Key changes

### 1. Port allocation table (single source of truth)

Located in a header comment at the top of `argocd.sh`. List every service, its host port, cluster port, and where it's defined. Update this table whenever you add or change a port mapping.

### 2. Port conflict resolution (argocd-server ports patched, not Traefik)

Instead of patching Traefik off 80/443 (old approach), the script patches argocd-server's Service ports:

```bash
kubectl patch svc argocd-server -n argocd --type='json' -p='[
  {"op": "replace", "path": "/spec/ports/0/port", "value": 8081},
  {"op": "replace", "path": "/spec/ports/1/port", "value": 8443}
]'
```

Traefik keeps its default 80/443 — no conflict.

### 3. Port conflict detection

The bootstrap script now detects conflicts before binding:
- Checks if the target host port is in use (`lsof -i :<port>`)
- On macOS, uses `lsof`; on Linux, uses `ss -tln`
- If in use, either falls back (registry: tries 50000→50004) or fails with a clear error + diagnostic command

### 4. HTTPS/TLS for ArgoCD

- Self-signed cert generated via openssl during bootstrap: `openssl req -x509 -newkey rsa:4096 -nodes -keyout ... -out ... -days 365 -subj "/CN=localhost/O=ArgoCD"`
- TLS Secret created in argocd namespace: `kubectl create secret tls argocd-tls -n argocd --cert=... --key=...`
- `argo-ingress.yaml` targets argocd-server's HTTPS service port (8443) and references the TLS Secret

### 5. Configurable app ports

Go app reads port from `PORT` environment variable (defaults to 8090).

```go
port := os.Getenv("PORT")
if port == "" { port = "8090" }
log.Fatal(http.ListenAndServe(":"+port, nil))
```

## Manual verification

```bash
# Verify cluster boots cleanly
./argocd.sh

# Verify HTTPS access
curl -k https://localhost:8443

# Verify HTTP access
curl http://localhost:8081

# Verify Go app
curl http://localhost:8090
```
