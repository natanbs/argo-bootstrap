#############################################################################
# Full Bootstrap of ArgoCD with Go Web server using K3d and local registry #
############################################################################

# Usage
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] || [[ "$1" == "" ]]; then
	echo
	echo "Usage:"
	echo "$0 <git-token>     # If app in private repo"
	echo
	exit 1
else
	token=$1
fi

brew list k3d >/dev/null || brew install k3d

echo K3D Create cluster with the registry
k3d cluster create cluster-argo --port '8080:80@loadbalancer' --port '8443:443@loadbalancer' --port '8090:8090@loadbalancer'

echo Create ArgoCD
kubectl create namespace argocd
helm repo add argocd https://dandydeveloper.github.io/charts/
cd helm
helm dependency build
cd -
helm upgrade --install -n argocd argocd helm --create-namespace

# kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get server IP
IP=$(ipconfig getifaddr en0)
# Patch the aergocd service as a load balancer using the server's IP
kubectl patch svc argocd-server -n argocd -p '{"spec" : {"type": "LoadBalancer", "externalIPs": ["'${IP}'"]}}'

# ArgoCD cli
brew list argocd >/dev/null || brew install argocd

echo "Waiting for initial-password..."
until kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; do
	sleep 5
done

# Init passwd
init_pass=$(argocd admin initial-password -n argocd | head -1)
echo $init_pass

echo Patch trafik conflicting ports. "80 > 81" "443 > 9443"
kubectl patch svc traefik -n kube-system --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/port", "value": 81},{"op": "replace", "path": "/spec/ports/0/nodePort", "value": 32081},{"op": "replace", "path": "/spec/ports/1/port", "value": 9443},{"op": "replace", "path": "/spec/ports/1/nodePort", "value": 32443}]'

echo
sleep 30

echo Init login
argocd login localhost:8080 --username admin --password $init_pass --insecure

admin_pass=ChangeMe
echo Set admin password to $admin_pass - Change in the script
echo Change admin password
argocd account update-password --current-password $init_pass --new-password $admin_pass

echo Create argo application go-server
user=natanbs
echo Create secret for ghcr.io
kubectl create ns app-ns
kubectl create secret -n app-ns docker-registry ghcr-login-secret --docker-server=https://ghcr.io --docker-username=natanbs --docker-password=${token}
argocd repo add https://github.com/natanbs/go-server --username natanbs --password $token
# helm upgrade --install -n app-ns go-server oci://ghcr.io/natanbs/go-server

kubectl apply -f argo-app-go-server/go-server-argo-app.yaml
