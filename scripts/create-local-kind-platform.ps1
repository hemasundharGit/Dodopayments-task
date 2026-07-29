$ErrorActionPreference = "Stop"

Write-Host "Checking Docker daemon..."
docker version

Write-Host "Creating kind cluster named kind..."
kind create cluster --name kind
kubectl config use-context kind-kind

Write-Host "Installing NGINX Ingress for Task 1..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx `
  --namespace ingress-nginx `
  --create-namespace

Write-Host "Installing Sealed Secrets controller for Task 1..."
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets `
  --namespace kube-system

Write-Host "Installing Kyverno for Task 1 admission controls..."
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm upgrade --install kyverno kyverno/kyverno `
  --namespace kyverno `
  --create-namespace

Write-Host "Installing ArgoCD for Task 2 GitOps..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

Write-Host "Installing Istio demo profile for Task 3..."
istioctl install --set profile=demo -y

Write-Host "Waiting for core rollouts..."
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s
kubectl -n kyverno rollout status deploy/kyverno-admission-controller --timeout=180s
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
kubectl -n istio-system rollout status deploy/istiod --timeout=180s
kubectl -n istio-system rollout status deploy/istio-ingressgateway --timeout=180s

Write-Host "Platform ready."
kubectl get ns
