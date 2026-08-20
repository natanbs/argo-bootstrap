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

# Usage
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  echo
  echo "Usage:"  
  echo "$0 [git-token]     # If app in private repo (or set GITHUB_TOKEN)"
  echo
  echo "Environment variables:"
  echo "  GITHUB_TOKEN           GitHub personal access token for repo access"
  echo "  ARGOCD_INFRA_BRANCH    Branch for ApplicationSet (default: main)"
  echo "  ARGOCD_SESSION_EXPIRES Session duration (default: 720h = 30 days)"
  echo
  echo "If GITHUB_TOKEN is not set, you will be prompted for credentials."
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
      esac
      ;;
  esac
}

install_tool k3d

# Create GitHub repository credential for ArgoCD (declarative, no argocd CLI)
create_github_credential() {
  echo "Creating GitHub repository credential for ArgoCD..."
  kubectl apply -n argocd -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: github-repo-cred
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: https://github.com/natanbs/
  username: "${GITHUB_USER}"
  password: "${token}"
EOF
  echo "GitHub credential Secret created."
}

# Wait for repo-server to load the credential by polling the ArgoCD API
wait_for_repo_ready() {
  echo "Waiting for repo-server to load credential..."
  local max_attempts=30
  local attempt=0
  while [ $attempt -lt $max_attempts ]; do
    if curl -sf -u "admin:${admin_pass}" http://localhost:8081/api/v1/repositories 2>/dev/null | grep -q "argocd-infra"; then
      echo "Repository registered in ArgoCD."
      return 0
    fi
    attempt=$((attempt + 1))
    echo "  Attempt $attempt/$max_attempts — waiting 5s..."
    sleep 5
  done
  echo "ERROR: Repository not loaded after $((max_attempts * 5))s"
  return 1
}



# Deploy ApplicationSet from infra repo
deploy_applicationset() {
  echo "Deploying ApplicationSet from infra repo (branch: ${ARGOCD_INFRA_BRANCH})..."
  local tmpdir
  tmpdir=$(mktemp -d)
  local manifest="${tmpdir}/applicationset.yaml"
  
  curl -sL -u "${GITHUB_USER}:${token}" "https://raw.githubusercontent.com/natanbs/argocd-infra/${ARGOCD_INFRA_BRANCH}/applicationset.yaml" -o "$manifest"
  
  if [ ! -s "$manifest" ]; then
    echo "ERROR: Failed to fetch ApplicationSet manifest from branch ${ARGOCD_INFRA_BRANCH}"
    rm -rf "$tmpdir"
    exit 1
  fi
  
  kubectl apply -n argocd -f "$manifest"
  rm -rf "$tmpdir"
  echo "ApplicationSet deployed."
}

# Check all mapped host ports before binding
MAPPED_PORTS=(80 443)
check_mapped_ports() {
  for p in "${MAPPED_PORTS[@]}"; do
    if port_in_use "$p"; then
      echo "ERROR: Required port $p is already in use by $(lsof -i :$p 2>/dev/null | awk 'NR==2{print $1}')"
      echo "       Run: lsof -i :$p"
      exit 1
    fi
  done
}

echo Create registry if not exists
port_in_use() {
  local p=$1
  ss -tln 2>/dev/null | grep -q ":$p " && return 0
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
# Registry internal port in the Docker network is always 5000
REG_INT_PORT=5000
if ! k3d cluster list 2>/dev/null | grep -q 'cluster-argo'; then
  check_mapped_ports
  k3d cluster create --config k3d-config.yaml
else
  k3d cluster start cluster-argo
fi
k3d kubeconfig merge cluster-argo --switch-context 2>/dev/null || true
kubectl config use-context k3d-cluster-argo 2>/dev/null || true

echo Create ArgoCD
install_tool kubectl
kubectl get namespace argocd >/dev/null 2>&1 || kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Enable insecure mode (HTTP on port 8080, HTTPS on 8443) and configure session expiry
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p "{\"data\":{\"server.insecure\":\"true\",\"server.session.expires\":\"${ARGOCD_SESSION_EXPIRES}\"}}"

# Get server IP (cross-platform)
if [ "$OS" = "macos" ]; then
  IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
else
  IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ip -4 addr show 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | grep -v 127.0.0.1 | head -1 || echo "127.0.0.1")
fi
# Patch the aergocd service as a load balancer using the server's IP
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
echo $init_pass

echo
sleep 30

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

# Login with initial password
echo "Logging in to ArgoCD..."
if ! argocd login localhost:8081 --username admin --password "$init_pass" --plaintext; then
  echo "ERROR: ArgoCD login failed"
  kill $PF_PID 2>/dev/null
  exit 1
fi
echo "Login successful."

# Change admin password
echo "Changing ArgoCD admin password..."
yes | argocd account update-password --current-password "$init_pass" --new-password "$admin_pass"
sleep 2
if argocd login localhost:8081 --username admin --password "$admin_pass" --plaintext; then
  echo "VERIFIED: Password changed to: $admin_pass"
else
  echo "ERROR: Could not verify new password"
fi

# Register GitHub repo with ArgoCD (declarative Secret + API poll)
create_github_credential
wait_for_repo_ready || exit 1

# Deploy ApplicationSet (repo is now registered, credential is loaded)
deploy_applicationset

# Cleanup port-forward
kill $PF_PID 2>/dev/null

# Create the app image
echo Build image
cd ../argo-app-go-server && docker build -t argo-app-go-server:v1.0 . && cd -

echo Docker tag
docker tag argo-app-go-server:v1.0 "localhost:${REG_HOST_PORT}/argo-app-go-server:v1.0"

echo Docker push
docker push "localhost:${REG_HOST_PORT}/argo-app-go-server:v1.0"

echo Create argo application argo-app-go-server
kubectl apply -f ../argo-app-go-server/app/argo-app-go-server-app.yaml
