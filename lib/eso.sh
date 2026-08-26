#!/usr/bin/env bash
# eso.sh - External Secrets Operator setup library
# FR-011: Extract ESO setup code into lib/eso.sh module

set -euo pipefail

# Install External Secrets Operator via Helm
# Usage: install_eso_helm
install_eso_helm() {
  echo "[eso] Installing External Secrets Operator..."
  helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
  helm repo update external-secrets
  helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace external-secrets --create-namespace \
    --wait --timeout 120s
  echo "[eso] External Secrets Operator installed."
}

# Deploy external-secrets ArgoCD app
# Usage: create_eso_argocd_app
create_eso_argocd_app() {
  echo "[eso] Deploying external-secrets app..."
  kubectl create namespace apps-ns --dry-run=client -o yaml | kubectl apply -f -
  argocd app create external-secrets \
    --repo https://github.com/natanbs/external-secrets.git \
    --path . \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace external-secrets \
    --sync-policy automated \
    --auto-prune \
    --self-heal \
    --sync-option CreateNamespace=true \
    --sync-option ServerSideApply=true \
    --upsert
  argocd app wait external-secrets --timeout 120 --health
  echo "[eso] external-secrets app synced and healthy."
}

# Wait for ClusterSecretStore to be ready
# Usage: wait_for_cluster_secret_store
wait_for_cluster_secret_store() {
  echo "[eso] Waiting for ClusterSecretStore to be ready..."
  until kubectl get clustersecretstore kubernetes-store -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
    sleep 5
  done
  echo "[eso] ClusterSecretStore is ready."
}
