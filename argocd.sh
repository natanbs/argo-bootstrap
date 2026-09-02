#!/bin/bash
set -euo pipefail
#############################################################################
# Full Bootstrap of ArgoCD with Go Web server using K3d and local registry #
#############################################################################
# Port Allocation Table (single source of truth)
# Service         | Host   | Cluster | Service | Container | TLS | Defined In
# ----------------|--------|---------|---------|-----------|-----|-----------
# Traefik ingress | 80     | 80      | n/a     | n/a       | no  | k3d-config.yaml
# HTTPS ingress   | 443    | 443     | n/a     | n/a       | yes | k3d-config.yaml
# ArgoCD HTTP     | 8081   | 8081    | 8081    | 8080      | no  | k3d-config.yaml
# ArgoCD HTTPS    | 8443   | 8443    | 8443    | 8443      | yes | k3d-config.yaml
# Registry        | 50000  | 5000    | n/a     | n/a       | no  | argocd.sh (k3d registry create)
#
# Reserved host ports: 80, 443 (ingress); 50000-50004 (registry fallback)
# Note: Traefik terminates on the k3d loadbalancer; apps are path-routed via Ingress
#
# App Registration (in infra/argocd-infra/apps/*.yaml):
#   name       - Application name (e.g., vault, prometheus)
#   repoURL    - GitHub repo URL for the app
#   appPath    - Path within the repo (usually ".")
#   namespace  - Target Kubernetes namespace
# Adding a new app: create a YAML with these fields in the infra repo's apps/ directory.
# The ApplicationSet (cluster-apps) auto-discovers and deploys it on next sync.

# Source library modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/eso.sh"
source "$SCRIPT_DIR/lib/vault.sh"

# Usage
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  echo
  echo "Usage:"  
  echo "$0 [git-token]     # Pass token as argument, or set GITHUB_TOKEN env var"
  echo
  echo "Environment variables:"
  echo "  GITHUB_TOKEN           GitHub personal access token for repo access"
  echo "  ARGOCD_INFRA_BRANCH    Branch for ApplicationSet (default: main)"
  echo "  ARGOCD_SESSION_EXPIRES Session duration (default: 720h = 30 days)"
  echo
  echo "If GITHUB_TOKEN is not set and no token argument provided, you will be prompted."
  exit 1
fi

# GitHub token input: $1 arg > GITHUB_TOKEN env var > interactive prompt
token="${1:-$GITHUB_TOKEN}"
if [ -z "$token" ]; then
  echo "GitHub token not found."
  read -p "GitHub username: " GITHUB_USER
  read -s -p "GitHub personal access token: " token
  echo
  if [ -z "$GITHUB_USER" ] || [ -z "$token" ]; then
    echo "ERROR: GitHub username and token are required."
    exit 1
  fi
else
  GITHUB_USER="${GITHUB_USER:-natanbs}"
fi

# Configuration
ARGOCD_SESSION_EXPIRES="${ARGOCD_SESSION_EXPIRES:-720h}"
ARGOCD_INFRA_BRANCH="${ARGOCD_INFRA_BRANCH:-main}"

# Log all output to file
LOG_FILE="/tmp/argocd.log"
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== argocd.sh started at $(date) ==="
echo "Log file: $LOG_FILE"

# Detect OS and architecture
OS=""
ARCH=""
case "$(uname -s)" in
  Darwin) OS="macos"; ARCH=$(uname -m) ;;
  Linux)  OS="linux"; ARCH=$(uname -m) ;;
  *)      echo "Unsupported OS. Only macOS and Linux are supported."; exit 1 ;;
esac
[ "$ARCH" = "x86_64" ] && ARCH="amd64"
[ "$ARCH" = "aarch64" ] && ARCH="arm64"

# Install tool if not present
install_tool() {
  local tool=$1
  command -v "$tool" >/dev/null 2>&1 && return 0

  echo "Installing $tool..."
  case "$OS" in
    macos)
      local pkg="$tool"
      [ "$tool" = "kubectl" ] && pkg="kubernetes-cli"
      brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg"
      ;;
    linux)
      case "$tool" in
        k3d)
          curl -sL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
          ;;
        kubectl)
          local ver
          ver=$(curl -sL https://dl.k8s.io/release/stable.txt) || { echo "Failed to fetch kubectl version"; exit 1; }
          curl -sL "https://dl.k8s.io/release/${ver}/bin/linux/${ARCH}/kubectl" -o kubectl || { echo "Failed to download kubectl"; exit 1; }
          chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl
          ;;
        argocd)
          local ver
          ver=$(curl -sL "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
          [ -z "$ver" ] && { echo "Failed to get latest argocd version"; exit 1; }
          curl -sL "https://github.com/argoproj/argo-cd/releases/download/${ver}/argocd-linux-${ARCH}" -o argocd || { echo "Failed to download argocd"; exit 1; }
          chmod +x argocd && sudo mv argocd /usr/local/bin/argocd
          ;;
        jq)
          if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -qq && sudo apt-get install -y -qq jq
          elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y jq
          else
            curl -sL "https://github.com/jqlang/jq/releases/latest/download/jq-linux-${ARCH}" -o /tmp/jq || { echo "Failed to download jq"; exit 1; }
            chmod +x /tmp/jq && sudo mv /tmp/jq /usr/local/bin/jq
          fi
          ;;
      esac
      ;;
  esac
}

install_tool k3d


# Deploy ApplicationSet from infra repo
deploy_applicationset() {
  echo "Deploying ApplicationSet from infra repo (branch: ${ARGOCD_INFRA_BRANCH})..."
  local tmpdir
  tmpdir=$(mktemp -d)
  local manifest="${tmpdir}/applicationset.yaml"
  
  curl -sL -u "${GITHUB_USER}:${token}" "https://raw.githubusercontent.com/natanbs/argocd-infra/${ARGOCD_INFRA_BRANCH}/applicationset.yaml" -o "$manifest"
  local curl_exit=$?
  
  if [ $curl_exit -ne 0 ] || [ ! -s "$manifest" ]; then
    echo "ERROR: Failed to fetch ApplicationSet manifest from branch ${ARGOCD_INFRA_BRANCH} (curl exit: $curl_exit)"
    rm -rf "$tmpdir"
    exit 1
  fi
  
  kubectl apply -n argocd -f "$manifest"
  rm -rf "$tmpdir"
  echo "ApplicationSet deployed."
}

echo Create registry if not exists
port_in_use() {
  local p=$1
  lsof -i :"$p" 2>/dev/null | grep -q LISTEN && return 0
  return 1
}
REG_NAME="k3d-reg"
REG_HOST_PORT=50000
if docker inspect "$REG_NAME" >/dev/null 2>&1; then
  echo "Registry container already exists, skipping creation"
elif ! k3d registry list 2>/dev/null | grep -q "$REG_NAME"; then
  # Fallback loop: try ports 50000-50004
  for port in {50000..50004}; do
    if ! port_in_use "$port"; then
      REG_HOST_PORT=$port
      break
    fi
    echo "Port $port is in use, trying next..."
  done
  if port_in_use "$REG_HOST_PORT"; then
    echo "ERROR: All registry ports 50000-50004 are in use."
    echo "       Free a port and re-run."
    exit 1
  fi
  k3d registry create reg -p "$REG_HOST_PORT"
  docker update --restart unless-stopped k3d-reg
fi

echo K3D Create cluster with the registry
if ! k3d cluster list 2>/dev/null | grep -q 'cluster-argo'; then
  k3d cluster create --config k3d-config.yaml || { echo "ERROR: Failed to create k3d cluster"; exit 1; }
else
  k3d cluster start cluster-argo
fi
k3d kubeconfig merge cluster-argo --switch-context 2>/dev/null || true
kubectl config use-context k3d-cluster-argo 2>/dev/null || true

echo Create ArgoCD
install_tool kubectl
kubectl get namespace argocd >/dev/null 2>&1 || kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || { echo "ERROR: Failed to install ArgoCD manifests"; exit 1; }

# Enable insecure mode (HTTP on port 8080, HTTPS on 8443) and configure session expiry
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p "{\"data\":{\"server.insecure\":\"true\",\"server.session.expires\":\"${ARGOCD_SESSION_EXPIRES}\"}}"

# Get server IP (cross-platform)
if [ "$OS" = "macos" ]; then
  IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
else
  IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ip -4 addr show 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | grep -v 127.0.0.1 | head -1 || echo "127.0.0.1")
fi
# Patch the argocd service as a load balancer using the server's IP
kubectl patch svc argocd-server -n argocd -p '{"spec" : {"type": "LoadBalancer", "externalIPs": ["'${IP}'"]}}'

# Patch argocd-server ports to avoid Traefik conflict (Traefik keeps default 80/443)
kubectl patch svc argocd-server -n argocd --type='json' -p='[
  {"op": "replace", "path": "/spec/ports/0/port", "value": 8081},
  {"op": "replace", "path": "/spec/ports/0/targetPort", "value": 8080},
  {"op": "replace", "path": "/spec/ports/1/port", "value": 8443},
  {"op": "replace", "path": "/spec/ports/1/targetPort", "value": 8443}
]'

# ArgoCD cli
install_tool argocd

echo "Waiting for ArgoCD server to be ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "Waiting for initial-password secret..."
until kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; do
	sleep 5
done

# Read password directly from secret (avoids argocd CLI connection issue)
init_pass=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)

echo

# ArgoCD requires: 8+ chars, uppercase, lowercase, digit, special char
admin_pass="Changeme@1"

# Start port-forward and keep alive for login, password change, and repo registration
echo "Starting port-forward to ArgoCD..."
kubectl port-forward -n argocd svc/argocd-server 8081:8081 &
PF_PID=$!
sleep 5

until curl -sf http://localhost:8081/healthz > /dev/null 2>&1; do
  sleep 2
done
echo "Port-forward ready."

# Login with initial password (retry up to 5 times — port-forward may be flaky on fresh deploy)
echo "Logging in to ArgoCD..."
login_ok=false
for attempt in 1 2 3 4 5; do
  if argocd login localhost:8081 --username admin --password "$init_pass" --plaintext 2>/dev/null; then
    login_ok=true
    break
  fi
  echo "  Login attempt $attempt failed, retrying in 5s..."
  sleep 5
done
if [ "$login_ok" != "true" ]; then
  echo "ERROR: ArgoCD login failed after 5 attempts"
  kill $PF_PID 2>/dev/null || true
  exit 1
fi
echo "Login successful."

# Change admin password
echo "Changing ArgoCD admin password..."
yes | argocd account update-password --current-password "$init_pass" --new-password "$admin_pass" || true
sleep 2
if argocd login localhost:8081 --username admin --password "$admin_pass" --plaintext; then
  echo "Password changed successfully."
else
  echo "ERROR: Could not verify new password"
fi

# Register all GitHub repos with ArgoCD
echo "Registering GitHub repositories with ArgoCD..."
install_tool jq
tmpdir=$(mktemp -d)

# Register the infra repo first
argocd repo add https://github.com/natanbs/argocd-infra.git --username "$GITHUB_USER" --password "$token" --upsert || echo "WARNING: Failed to add infra repo (may already exist)"

# Fetch app definitions and register each repo
# ApplicationSet reads from apps/infra/*.yaml and apps/applicative/*.yaml

for subdir in infra applicative; do
  for appfile in $(curl -sL -u "${GITHUB_USER}:${token}" "https://api.github.com/repos/natanbs/argocd-infra/contents/apps/${subdir}?ref=${ARGOCD_INFRA_BRANCH}" 2>/dev/null | jq -r '.[] | select(.name | endswith(".yaml")) | .download_url' 2>/dev/null); do
    repo_url=$(curl -sL -u "${GITHUB_USER}:${token}" "$appfile" 2>/dev/null | grep 'repoURL:' | awk '{print $2}')
    if [ -n "$repo_url" ]; then
      echo "  Adding $repo_url ..."
      argocd repo add "$repo_url" --username "$GITHUB_USER" --password "$token" --upsert || echo "  WARNING: Failed to add $repo_url (may already exist)"
    else
      echo "  WARNING: Could not fetch repoURL from $appfile (skipping)"
    fi
  done
done
rm -rf "$tmpdir"
echo "All repositories registered."

# Register external-secrets repo (referenced by ESO ArgoCD app, not in apps/*.yaml)
argocd repo add https://github.com/natanbs/external-secrets.git --username "$GITHUB_USER" --password "$token" --upsert || echo "WARNING: Failed to add external-secrets repo (may already exist)"

# Install External Secrets Operator and deploy via ArgoCD
install_eso_helm
create_eso_argocd_app
wait_for_cluster_secret_store

# Create vault-tls source secret and unseal placeholder
VAULT_REPO="$SCRIPT_DIR/../infra/vault"
create_vault_tls_secret "$VAULT_REPO"
create_vault_unseal_placeholder

# Deploy ApplicationSet (remaining apps)
deploy_applicationset

# Wait for vault-tls, then init and unseal vault
wait_for_vault_tls
init_vault "$VAULT_REPO"
unseal_vault
enable_vault_secrets "$VAULT_REPO"
# Provision ESO Kubernetes auth + role es-vault + secret/aws/env so
# applicative apps recover their secrets declaratively after a rebuild.
provision_es_vault "$VAULT_REPO"
# Seed email/* + llm/opencode (SMTP, 3rd-party provider creds, analyst API key)
# from Infisical so the email-env/email-bulk/analyst ExternalSecrets sync on a
# fresh cluster (no manual step). Sources: EMAIL_DOTENV and LLM_DOTENV (paths to
# `infisical export` dotenvs for the email and llm-b-ete projects).
seed_email_vault "$VAULT_REPO" "${EMAIL_DOTENV:-}" "${LLM_DOTENV:-}"
verify_vault_status

# Cleanup port-forward
kill $PF_PID 2>/dev/null || true

# Create the app image
echo Build image
cd ../argo-app-go-server && docker build -t argo-app-go-server:v1.0 . && cd -

echo Docker tag
docker tag argo-app-go-server:v1.0 "localhost:${REG_HOST_PORT}/argo-app-go-server:v1.0"

echo Docker push
docker push "localhost:${REG_HOST_PORT}/argo-app-go-server:v1.0"

echo Create argo application argo-app-go-server
kubectl apply -f ../argo-app-go-server/app/argo-app-go-server-app.yaml
