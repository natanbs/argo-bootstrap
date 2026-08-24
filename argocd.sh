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

# Register all GitHub repos with ArgoCD
echo "Registering GitHub repositories with ArgoCD..."
tmpdir=$(mktemp -d)

# Register the infra repo first
argocd repo add https://github.com/natanbs/argocd-infra.git --username "$GITHUB_USER" --password "$token" --upsert

# Fetch app definitions and register each repo
curl -sL -u "${GITHUB_USER}:${token}" "https://raw.githubusercontent.com/natanbs/argocd-infra/${ARGOCD_INFRA_BRANCH}/apps/*.yaml" -o "$tmpdir/apps.txt" 2>/dev/null || true

for appfile in $(curl -sL -u "${GITHUB_USER}:${token}" "https://api.github.com/repos/natanbs/argocd-infra/contents/apps?ref=${ARGOCD_INFRA_BRANCH}" 2>/dev/null | python3 -c "import sys,json; [print(f['download_url']) for f in json.load(sys.stdin) if f['name'].endswith('.yaml')]" 2>/dev/null); do
  repo_url=$(curl -sL -u "${GITHUB_USER}:${token}" "$appfile" | grep 'repoURL:' | awk '{print $2}')
  if [ -n "$repo_url" ]; then
    echo "  Adding $repo_url ..."
    argocd repo add "$repo_url" --username "$GITHUB_USER" --password "$token" --upsert
  fi
done
rm -rf "$tmpdir"
echo "All repositories registered."

# Install External Secrets Operator CRDs before any apps that depend on them
echo "Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update external-secrets
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --wait --timeout 120s
echo "External Secrets Operator installed."

# Deploy external-secrets app first (other apps depend on its ClusterSecretStore)
echo "Deploying external-secrets app..."
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
echo "external-secrets app synced and healthy."

# Wait for ClusterSecretStore to be ready (vault's ExternalSecret depends on it)
echo "Waiting for ClusterSecretStore to be ready..."
until kubectl get clustersecretstore kubernetes-store -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
  sleep 5
done
echo "ClusterSecretStore is ready."

# Create vault-tls source secret in apps-ns (vault's ExternalSecret depends on it)
echo "Creating vault-tls source secret..."
VAULT_REPO="../infra/vault"
if [[ -f "$VAULT_REPO/scripts/vault-tls.sh" ]]; then
  bash "$VAULT_REPO/scripts/vault-tls.sh"
else
  echo "ERROR: vault-tls.sh not found at $VAULT_REPO/scripts/vault-tls.sh"
  echo "Please run it manually to create the vault-tls secret in apps-ns"
fi

# Create vault-unseal-keys secret so vault pods can start
echo "Creating vault-unseal-keys secret..."
VAULT_REPO="../infra/vault"
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -
kubectl -n vault create secret generic vault-unseal-keys \
  --from-literal=key1=PLACEHOLDER \
  --from-literal=key2=PLACEHOLDER \
  --from-literal=key3=PLACEHOLDER \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy ApplicationSet (remaining apps)
deploy_applicationset

# Wait for vault-tls secret to be synced to vault namespace (ESO must sync before vault starts TLS listener)
echo "Waiting for vault-tls secret in vault namespace..."
until kubectl get secret vault-tls -n vault >/dev/null 2>&1; do
  sleep 5
done
echo "vault-tls secret is ready."

# Initialize and unseal vault on fresh cluster
# VAULT_ADDR must be 127.0.0.1 so vault CLI talks to the local process,
# not to another node via the internal service address.
VAULT_LOCAL_ADDR="https://127.0.0.1:8200"

# Helper: run vault CLI inside a pod with correct VAULT_ADDR
vault_exec() {
  local pod=$1; shift
  kubectl exec -n vault "$pod" -- sh -c "VAULT_ADDR='$VAULT_LOCAL_ADDR' $*"
}

# Diagnostic: show what VAULT_ADDR is inside a vault pod
echo "Checking VAULT_ADDR inside vault-0..."
kubectl exec -n vault vault-0 -- sh -c 'echo "VAULT_ADDR=$VAULT_ADDR"' 2>/dev/null || echo "(could not read VAULT_ADDR)"

echo "Waiting for vault-0 API to be reachable..."
TIMEOUT=60
COUNT=0
until vault_exec vault-0 "vault status -tls-skip-verify -format=json" 2>/dev/null | grep -q '"initialized"'; do
  COUNT=$((COUNT + 1))
  if [ $COUNT -ge $TIMEOUT ]; then
    echo "ERROR: Timed out waiting for vault-0 API after $((TIMEOUT * 5))s"
    exit 1
  fi
  sleep 5
done
echo "vault-0 API is reachable."

echo "Initializing vault..."
INIT_JSON=$(vault_exec vault-0 "vault operator init -key-shares=5 -key-threshold=3 -format=json -tls-skip-verify")
if [[ -z "$INIT_JSON" ]] || ! echo "$INIT_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  echo "ERROR: vault operator init failed or returned invalid JSON"
  echo "Output: $INIT_JSON"
  kill $PF_PID 2>/dev/null
  exit 1
fi
echo "$INIT_JSON" > "$VAULT_REPO/init.json"
echo "Vault initialized. Keys saved to $VAULT_REPO/init.json"

# Extract unseal keys
KEY1=$(echo "$INIT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['unseal_keys_b64'][0])")
KEY2=$(echo "$INIT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['unseal_keys_b64'][1])")
KEY3=$(echo "$INIT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['unseal_keys_b64'][2])")

# Update the secret with real keys
kubectl -n vault delete secret vault-unseal-keys
kubectl -n vault create secret generic vault-unseal-keys \
  --from-literal=key1="$KEY1" \
  --from-literal=key2="$KEY2" \
  --from-literal=key3="$KEY3"

# Unseal vault-0 (must be unsealed before StatefulSet creates vault-1)
echo "Unsealing vault-0..."
for key in "$KEY1" "$KEY2" "$KEY3"; do
  vault_exec vault-0 "vault operator unseal -tls-skip-verify '$key'" || { echo "ERROR: failed to unseal vault-0 with key"; exit 1; }
done
echo "vault-0 unsealed. Waiting for it to be ready..."
if ! kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=120s; then
  echo "ERROR: vault-0 did not become Ready within 120s"
  exit 1
fi
# Verify vault-0 is actually unsealed
SEALED=$(vault_exec vault-0 "vault status -tls-skip-verify -format=json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['sealed'])" 2>/dev/null)
if [ "$SEALED" != "False" ]; then
  echo "ERROR: vault-0 is still sealed after unseal (sealed=$SEALED)"
  exit 1
fi
echo "vault-0 verified: sealed=False"

# Unseal vault-1 (must be unsealed before StatefulSet creates vault-2)
echo "Waiting for vault-1 to join raft cluster (initialized)..."
TIMEOUT=60
COUNT=0
until vault_exec vault-1 "vault status -tls-skip-verify -format=json" 2>/dev/null | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('initialized') else 1)"; do
  COUNT=$((COUNT + 1))
  if [ $COUNT -ge $TIMEOUT ]; then
    echo "ERROR: Timed out waiting for vault-1 to initialize after $((TIMEOUT * 5))s"
    exit 1
  fi
  sleep 5
done
echo "vault-1 joined raft cluster."
echo "Unsealing vault-1..."
for key in "$KEY1" "$KEY2" "$KEY3"; do
  RESULT=$(vault_exec vault-1 "vault operator unseal -tls-skip-verify '$key'" 2>&1)
  UNSEAL_EXIT=$?
  echo "  key applied, sealed=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sealed','?'))" 2>/dev/null || echo "parse-error")"
  if [ $UNSEAL_EXIT -ne 0 ]; then
    echo "ERROR: failed to unseal vault-1 (exit $UNSEAL_EXIT): $RESULT"
    exit 1
  fi
done
echo "vault-1 unsealed. Waiting for it to be ready..."
if ! kubectl wait --for=condition=Ready pod/vault-1 -n vault --timeout=120s; then
  echo "ERROR: vault-1 did not become Ready within 120s"
  exit 1
fi
# Verify vault-1 is actually unsealed
SEALED=$(vault_exec vault-1 "vault status -tls-skip-verify -format=json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['sealed'])" 2>/dev/null)
if [ "$SEALED" != "False" ]; then
  echo "ERROR: vault-1 is still sealed after unseal (sealed=$SEALED)"
  exit 1
fi
echo "vault-1 verified: sealed=False"

# Unseal vault-2
echo "Waiting for vault-2 to join raft cluster (initialized)..."
TIMEOUT=60
COUNT=0
until vault_exec vault-2 "vault status -tls-skip-verify -format=json" 2>/dev/null | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('initialized') else 1)"; do
  COUNT=$((COUNT + 1))
  if [ $COUNT -ge $TIMEOUT ]; then
    echo "ERROR: Timed out waiting for vault-2 to initialize after $((TIMEOUT * 5))s"
    exit 1
  fi
  sleep 5
done
echo "vault-2 joined raft cluster."
echo "Unsealing vault-2..."
for key in "$KEY1" "$KEY2" "$KEY3"; do
  RESULT=$(vault_exec vault-2 "vault operator unseal -tls-skip-verify '$key'" 2>&1)
  UNSEAL_EXIT=$?
  echo "  key applied, sealed=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sealed','?'))" 2>/dev/null || echo "parse-error")"
  if [ $UNSEAL_EXIT -ne 0 ]; then
    echo "ERROR: failed to unseal vault-2 (exit $UNSEAL_EXIT): $RESULT"
    exit 1
  fi
done
echo "vault-2 unsealed. Waiting for it to be ready..."
if ! kubectl wait --for=condition=Ready pod/vault-2 -n vault --timeout=120s; then
  echo "ERROR: vault-2 did not become Ready within 120s"
  exit 1
fi
# Verify vault-2 is actually unsealed
SEALED=$(vault_exec vault-2 "vault status -tls-skip-verify -format=json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['sealed'])" 2>/dev/null)
if [ "$SEALED" != "False" ]; then
  echo "ERROR: vault-2 is still sealed after unseal (sealed=$SEALED)"
  exit 1
fi
echo "vault-2 verified: sealed=False"

echo "Vault initialized and unsealed."

# Final summary: print all vault statuses
echo "--- Vault Cluster Status ---"
for i in 0 1 2; do
  STATUS=$(vault_exec "vault-$i" "vault status -tls-skip-verify -format=json" 2>/dev/null)
  if [ -n "$STATUS" ]; then
    echo "vault-$i: sealed=$(echo "$STATUS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'sealed={d[\"sealed\"]} initialized={d[\"initialized\"]} progress={d.get(\"progress\",\"?\")}')")"
  else
    echo "vault-$i: (could not get status)"
  fi
done
echo "---"

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
