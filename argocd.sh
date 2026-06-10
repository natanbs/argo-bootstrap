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
  token=$1
fi

brew list k3d >/dev/null || brew install k3d

echo Cretate registry
k3d registry create reg -p 50000
docker rename k3d-reg localhost

echo K3D Create cluster with the registry
#k3d cluster create cluster1 --no-lb --k3s-arg "--disable=traefik" --registry-use k3d-reg:50000 --agents 2 --servers 1 --port "8081:80@loadbalancer" -p "8443:443@loadbalancer"
#k3d cluster create cluster-argo --agents 2 --port '8081:80@loadbalancer' --port '8443:443@loadbalancer' --port '8090:8090@loadbalancer' --registry-use k3d-reg:50000
#k3d cluster create cluster-argo --agents 2 --port '8081:80@loadbalancer' --port '8443:443@loadbalancer' --port '8090:8090@loadbalancer' --port '50001:50000@loadbalancer' --registry-use k3d-reg:50000
k3d cluster create cluster-argo --agents 2 --port '8081:80@loadbalancer' --port '8443:443@loadbalancer' --port '8090:8090@loadbalancer' --port '50000:5000@loadbalancer' --registry-use localhost:50000

echo Create ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

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

echo Add argocd ingress
kubectl apply -f argo-ingress.yaml
#echo Port Forwarding 8080:443
#kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &

echo
sleep 30

echo Init login
argocd login localhost:8081 --username admin --password $init_pass --insecure

admin_pass=ChangeMe
echo Set admin password to $admin_pass - Change in the script
echo Change admin password
argocd account update-password --current-password $init_pass --new-password $admin_pass

echo Patch trafik conflicting ports. "80 > 81" "443 > 9443"
kubectl patch svc traefik -n kube-system --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/port", "value": 81},{"op": "replace", "path": "/spec/ports/0/nodePort", "value": 32081},{"op": "replace", "path": "/spec/ports/1/port", "value": 9443},{"op": "replace", "path": "/spec/ports/1/nodePort", "value": 32443}]'

# Create the app image
echo Build image
cd ../go-server
docker build -t go-server:v1.0 .
cd -

echo Docker tag
docker tag go-server:v1.0 localhost:50000/go-server:v1.0

echo Docker push
docker push localhost:50000/go-server:v1.0

#echo kubectl run
#kubectl run go-server --image localhost:5000/go-server:v0.1

# Deploy go-server
# cd argo-app-go-server
# kubectl create ns go-server-ns
# kubectl apply -f go-server-deploy.yaml
# kubectl apply -f go-server-svc.yaml
##kubectl apply -f go-server-ingress.yaml
# Patch the go-server service as a load balancer using the server's IP
#kubectl patch svc go-server -n go-server-ns -p '{"spec" : {"type": "LoadBalancer", "externalIPs": ["'${IP}'"]}}'
# cd -

echo Create argo application go-server
argocd repo add https://github.com/natanbs/argo-bootstrap --username natanbs --password $token
kubectl apply -f argo-app-go-server/go-server-app.yaml
