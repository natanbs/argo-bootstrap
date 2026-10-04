# Data Model: Restore ArgoCD Ingress

## Overview
This feature adds a declarative Kubernetes Ingress resource. No data entities or state changes to application data — purely networking/routing configuration.

## Entities

### Kubernetes Ingress (argocd-server-ingress)
Represents HTTP routing rule for ArgoCD.

**Fields**:
- apiVersion: networking.k8s.io/v1
- kind: Ingress
- metadata.name: argocd-server-ingress
- metadata.namespace: argocd
- metadata.annotations: router entrypoint/tls settings for Traefik
- spec.ingressClassName: traefik
- spec.rules[0].host: argocd.lab
- spec.rules[0].http.paths[0].path: /
- spec.rules[0].http.paths[0].pathType: Prefix
- spec.rules[0].http.paths[0].backend.service.name: argocd-server
- spec.rules[0].http.paths[0].backend.service.port.number: 8081

**Validation Rules**:
- Host must be unique within cluster (no other Ingress claims argocd.lab)
- Backend service must exist in namespace argocd
- Port must match Service HTTP port

**State**: Declarative; managed by kubectl apply. No runtime state transitions.
