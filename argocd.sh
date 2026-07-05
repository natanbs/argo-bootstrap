#############################################################################
# Full Bootstrap of ArgoCD with Go Web server using K3d and local registry #
############################################################################

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
  if port_in_use $REG_HOST_PORT; then
    echo "Port $REG_HOST_PORT already in use, using port 50001 instead"
    REG_HOST_PORT=50001
  fi
  k3d registry create reg -p "$REG_HOST_PORT"
fi

echo K3D Create cluster with the registry
# Registry internal port in the Docker network is always 5000
REG_INT_PORT=5000
if ! k3d cluster list 2>/dev/null | grep -q 'cluster-argo'; then
  k3d cluster create cluster-argo --agents 2 \
    --port '8081:80@loadbalancer' \
    --port '8443:443@loadbalancer' \
    --port '8090:8090@loadbalancer' \
    --registry-use "${REG_NAME}:${REG_INT_PORT}"
fi

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
#echo Port Forwarding 8080:443
#kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &

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

echo Patch trafik conflicting ports. "80 > 81" "443 > 9443"
kubectl patch svc traefik -n kube-system --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/port", "value": 81},{"op": "replace", "path": "/spec/ports/0/nodePort", "value": 32081},{"op": "replace", "path": "/spec/ports/1/port", "value": 9443},{"op": "replace", "path": "/spec/ports/1/nodePort", "value": 32443}]'

# Create the app image
echo Build image
cd ../argo-app-go-server && docker build -t argo-app-go-server:v1.0 . && cd -

echo Docker tag
docker tag argo-app-go-server:v1.0 "localhost:${REG_HOST_PORT}/argo-app-go-server:v1.0"

echo Docker push
docker push "localhost:${REG_HOST_PORT}/argo-app-go-server:v1.0"

echo Create argo application argo-app-go-server
kubectl apply -f ../argo-app-go-server/app/argo-app-go-server-app.yaml
