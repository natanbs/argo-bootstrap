echo Deleting k3d cluster
k3d cluster delete cluster-argo
echo Deleting k3d registry
k3d registry delete localhost
