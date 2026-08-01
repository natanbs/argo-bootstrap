#############################################################################
# Full Bootstrap of ArgoCD with Go Web server using K3d and local registry #
#############################################################################
# Port Allocation Table (single source of truth)
# Service         | Host   | Cluster | Service | Container | TLS | Defined In
# ----------------|--------|---------|---------|-----------|-----|-----------
# ArgoCD HTTP     | 8081   | 8081    | 8081    | 8080      | no  | argocd.sh (k3d --port, svc patch)
# ArgoCD HTTPS    | 8443   | 8443    | 8443    | 443       | yes | argocd.sh (k3d --port, svc patch)
# Go Server       | 8090   | 8090    | 8090    | 8090      | no  | argocd.sh (k3d --port), deployment.yaml
# Registry        | 50000  | 5000    | n/a     | n/a       | no  | argocd.sh (k3d registry create)
#
# Reserved host port ranges: 8081, 8443, 8090 (apps); 50000-50004 (registry fallback)
# Note: Traefik keeps its default 80/443 — no patching needed

# Usage
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  echo
  echo "Usage:"  
  echo "$0 <git-token>     # If app in private repo"
  echo
  exit 1
else
  token="${1:-$GITHUB_TOKEN}"
fi

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

# Check all mapped host ports before binding
MAPPED_PORTS=(8081 8443 8090)
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
  {"op": "replace", "path": "/spec/ports/1/port", "value": 8443}
]'

# ArgoCD cli
install_tool argocd

echo "Waiting for initial-password..."
until kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; do
	sleep 5
done

# Init passwd
init_pass=$(argocd admin initial-password -n argocd | head -1)
echo $init_pass

echo Add argocd ingress
kubectl apply -f argo-ingress.yaml

echo Generate self-signed TLS certificate for HTTPS
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout /tmp/argocd-tls-key.pem \
  -out /tmp/argocd-tls-cert.pem \
  -days 365 -subj "/CN=localhost/O=ArgoCD" 2>/dev/null
kubectl create secret tls argocd-tls -n argocd \
  --cert=/tmp/argocd-tls-cert.pem \
  --key=/tmp/argocd-tls-key.pem 2>/dev/null
rm -f /tmp/argocd-tls-*.pem

echo
sleep 30

admin_pass=ChangeMe

# Login with initial password (first run) or admin password (re-run)
if argocd login localhost:8081 --username admin --password $init_pass --insecure 2>/dev/null; then
  echo Set admin password to $admin_pass
  echo Change admin password
  argocd account update-password --current-password $init_pass --new-password $admin_pass
else
  argocd login localhost:8081 --username admin --password $admin_pass --insecure
fi

# Create the app image
echo Build image
cd ../argo-app-go-server && docker build -t argo-app-go-server:v1.0 . && cd -

echo Docker tag
docker tag argo-app-go-server:v1.0 "localhost:${REG_HOST_PORT}/argo-app-go-server:v1.0"

echo Docker push
docker push "localhost:${REG_HOST_PORT}/argo-app-go-server:v1.0"

echo Create argo application argo-app-go-server
kubectl apply -f ../argo-app-go-server/app/argo-app-go-server-app.yaml
