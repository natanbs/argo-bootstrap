# Quickstart Validation Guide

## Prerequisites
- k3d cluster running with Traefik
- ArgoCD installed and healthy in namespace argocd
- Hostname argocd.lab resolves to cluster host IP

## Steps to Validate

1. Ensure the ingress manifest exists:
```bash
cat argo-ingress.yaml
```

2. Apply the ingress (if not already applied):
```bash
kubectl apply -f argo-ingress.yaml
```

3. Verify ingress is created:
```bash
kubectl get ingress -n argocd
kubectl describe ingress argocd-server-ingress -n argocd
```

4. Test HTTP access via ingress:
```bash
curl -i -H "Host: argocd.lab" http://127.0.0.1/
```

Expected: HTTP 200 OK or redirect to /login with ArgoCD login page content.

5. Test browser access:
- Open http://argocd.lab/ in browser → ArgoCD login UI loads

6. Verify direct LoadBalancer access still works:
```bash
curl -i http://<host-ip>:8081/
```

Expected: Still accessible (non-ingress path).

## Success Criteria
- curl with Host: argocd.lab returns HTTP 2xx/3xx and ArgoCD content
- No TLS errors in browser
- Both ingress path and direct 8081/8443 ports remain functional
