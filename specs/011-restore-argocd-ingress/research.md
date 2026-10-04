# Research: Restore ArgoCD Ingress

## Research Summary

Based on sibling repo analysis and existing bootstrap configuration, the correct approach is to restore `argo-ingress.yaml` with Traefik ingress matching the tech-companies pattern for plain HTTP.

## Key Findings

### 1. Historical manifest (for reference)
From git history (d39b17e), the original manifest routed to backend port 8443 with HTTPS scheme annotations. With `server.insecure=true` and the current Service patching in `argocd.sh`, that is not the right fit today.

### 2. Correct backend configuration
- ArgoCD runs with `server.insecure=true` (argocd.sh:195)
- Service `argocd-server` in namespace `argocd` exposes HTTP targetPort 8080 (patched to external 8081) and HTTPS targetPort 8443 (external 8443)
- For plain HTTP ingress to work without TLS redirects, route to the HTTP port: service port number should be 80? Or match target. But in the Service, the HTTP port is named/numbered as port 8081 externally; internally targetPort is 8080. For Ingress backend, we point to the Service port that forwards to the HTTP container port.

Looking at sibling: tech-companies routes to service port `number: 7070` (the container port). Similarly, for ArgoCD with `server.insecure=true`, the container serves HTTP on 8080. So Ingress backend should be `port.number: 8080` (service port number that targets 8080). Check the actual Service: in the current patched state, ports are [ {port:8081,targetPort:8080,name:...}, {port:8443,targetPort:8443,...}]. So the Service has port 8081 pointing to 8080. That means Ingress can target either port number — but better to target the named port or the correct port. Standard is to use the service port number; many examples use the container port number in the sense of the service's port that serves that traffic. Looking at sibling examples more precisely: analyst service listens on 8888 (container), Ingress backend port.number is 8888 — so it points to the service port that corresponds to the app's listening port. That matches.

### 3. Traefik plain HTTP pattern
tech-companies uses:
```yaml
annotations:
  traefik.ingress.kubernetes.io/router.entrypoints: web
  traefik.ingress.kubernetes.io/router.tls: "false"
spec:
  ingressClassName: traefik
  rules:
  - host: tech-companies.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tech-companies
            port:
              number: 7070
```

This avoids the default redirect to websecure when `--entryPoints.websecure.http.tls=true` is set.

### 4. ArgoCD service port
Since `argocd-server` Service exposes HTTP on port 8081 (targeting 8080), and HTTPS on 8443 (targeting 8443), for plain HTTP ingress we should route to port 8080? Wait — the service port number is what matters. If the Service's port is 8081 mapped to 8080, then Ingress backend port.number is 8081. But looking up how others do it: in the same cluster, apps define their own Service. For ArgoCD, it's the upstream Service. Let us look up the actual Service definition. From argocd.sh patch: they set port 0 to 8081 (target 8080), port 1 to 8443 (target 8443). So HTTP service port is 8081. But the container listens on 8080 when insecure. That means backend port.number should be 8081.

But siblings point to their app's container/listening port as the service port number in their own Services. Let us confirm: analyst Service likely has port 8888 -> targetPort 8888. So for ArgoCD's upstream Service (as patched), port 8081 is the service port. So Ingress should point to port 8081? That depends. Let us look up a typical ArgoCD Ingress example with insecure mode — usually you point to `argocd-server` service port `http` which is often 80 or the named port; but with custom patches, better to match the actual Service. But easier to look up: in the historical manifest, it pointed to port 8443 (HTTPS). With insecure HTTP on 8080 container port, and Service port 8081 mapped to it, the correct service port is 8081. However, many Ingresses point to the target port number as written in Service — in Kubernetes API, backend.service.port.number refers to the Service port (not necessarily container). So yes, 8081.

But this is awkward because we also have 8081 exposed via LoadBalancer. Another convention: some point to port "http" by name. But better to be explicit.

## Decision

Create `argo-ingress.yaml` with:
- metadata: name `argocd-server-ingress`, namespace `argocd`
- annotations (per tech-companies): `traefik.ingress.kubernetes.io/router.entrypoints: web`, `traefik.ingress.kubernetes.io/router.tls: "false"`
- ingressClassName: `traefik`
- host: `argocd.lab`, path `/`, pathType `Prefix`
- backend: service `argocd-server`, port number `8081` (matching current Service HTTP port mapping to container 8080)

This matches sibling conventions and works with ArgoCD in insecure mode.

## Rationale

- Plain HTTP entrypoint avoids Traefik's automatic TLS redirect (critical with `websecure.http.tls=true`)
- Points to HTTP backend on Service port 8081 which targets container 8080 (insecure)
- Consistent with other local `.lab` apps
- No changes to `argocd.sh` needed; manifest is applied during normal bootstrap flow (repo root manifests are typically applied if present)

## Alternatives Considered

1. Route to port 8443 with scheme annotations (old approach) — rejected because `server.insecure=true` means HTTP on 8080; mixing schemes is confusing and the old manifest had TLS-specific annotations.
2. Omit Traefik-specific annotations — would cause redirect to HTTPS on websecure; breaks plain HTTP access.
