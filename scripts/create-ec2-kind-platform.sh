#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.local/bin:${HOME}/go/bin:/usr/local/bin:/usr/local/go/bin:${PATH}"

CLUSTER_NAME="${CLUSTER_NAME:-ledger-secdevops}"

echo "[1/6] Checking Docker..."
docker info >/dev/null

echo "[2/6] Creating kind cluster: ${CLUSTER_NAME}"
if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  cat <<'EOF' | kind create cluster --name "${CLUSTER_NAME}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
EOF
fi
kubectl config use-context "kind-${CLUSTER_NAME}"

echo "[3/6] Installing ingress, Sealed Secrets, Kyverno, and ArgoCD..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo add sealed-secrets https://bitnami.github.io/sealed-secrets >/dev/null
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null
helm repo update >/dev/null

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.dnsPolicy=ClusterFirstWithHostNet

helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system

helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[4/6] Installing Istio demo profile..."
istioctl install --set profile=demo -y

echo "[5/6] Waiting for rollouts..."
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=240s
kubectl -n kyverno rollout status deploy/kyverno-admission-controller --timeout=240s
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n istio-system rollout status deploy/istiod --timeout=240s
kubectl -n istio-system rollout status deploy/istio-ingressgateway --timeout=240s

echo "[6/6] Platform status:"
kubectl get nodes -o wide
kubectl get pods -A

echo
echo "Platform ready."
echo "ArgoCD password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
echo "Use port-forward for ArgoCD:"
echo "kubectl -n argocd port-forward svc/argocd-server 8080:443"
