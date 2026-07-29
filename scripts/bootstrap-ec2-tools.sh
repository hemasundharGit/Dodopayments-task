#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
WORK_DIR="${HOME}/security-devops-tools"
GO_VERSION="${GO_VERSION:-1.23.5}"
ISTIO_VERSION="${ISTIO_VERSION:-1.24.2}"

mkdir -p "${BIN_DIR}" "${WORK_DIR}"

if ! grep -q "${BIN_DIR}" "${HOME}/.bashrc" 2>/dev/null; then
  echo "export PATH=\"${BIN_DIR}:\${HOME}/go/bin:\${PATH}\"" >> "${HOME}/.bashrc"
fi
export PATH="${BIN_DIR}:${HOME}/go/bin:/usr/local/go/bin:${PATH}"

echo "[1/8] Installing base packages..."
sudo apt-get update
sudo apt-get install -y \
  apt-transport-https \
  build-essential \
  ca-certificates \
  curl \
  dnsutils \
  git \
  gnupg \
  jq \
  lsb-release \
  openssl \
  pipx \
  python3 \
  python3-pip \
  ruby \
  ruby-dev \
  tar \
  unzip \
  wget

echo "[2/8] Installing Docker..."
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get install -y docker.io
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "${USER}"

echo "[3/8] Installing Kubernetes and platform CLIs..."
curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o "${BIN_DIR}/kubectl"
chmod +x "${BIN_DIR}/kubectl"

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

curl -fsSL https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 -o "${BIN_DIR}/kind"
chmod +x "${BIN_DIR}/kind"

curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

curl -fsSL https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 -o "${BIN_DIR}/minikube"
chmod +x "${BIN_DIR}/minikube"

curl -fsSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >/tmp/argocd-install.yaml
curl -fsSL https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 -o "${BIN_DIR}/argocd"
chmod +x "${BIN_DIR}/argocd"

curl -fsSL https://fluxcd.io/install.sh | sudo bash

curl -L "https://istio.io/downloadIstio" | ISTIO_VERSION="${ISTIO_VERSION}" sh -
cp "istio-${ISTIO_VERSION}/bin/istioctl" "${BIN_DIR}/istioctl"
chmod +x "${BIN_DIR}/istioctl"

echo "[4/8] Installing policy, secret, and supply-chain tools..."
curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/sigstore/cosign/main/install.sh | sudo sh -s -- -b /usr/local/bin

KYVERNO_URL="$(curl -fsSL https://api.github.com/repos/kyverno/kyverno/releases/latest | jq -r '.assets[] | select(.name | test("kyverno-cli_.*_linux_x86_64.tar.gz$")) | .browser_download_url' | head -n1)"
curl -fsSL "${KYVERNO_URL}" -o /tmp/kyverno.tar.gz
tar -xzf /tmp/kyverno.tar.gz -C /tmp kyverno
install -m 0755 /tmp/kyverno "${BIN_DIR}/kyverno"

KUBESEAL_URL="$(curl -fsSL https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | jq -r '.assets[] | select(.name | test("kubeseal-.*linux-amd64.tar.gz$")) | .browser_download_url' | head -n1)"
curl -fsSL "${KUBESEAL_URL}" -o /tmp/kubeseal.tar.gz
tar -xzf /tmp/kubeseal.tar.gz -C /tmp kubeseal
install -m 0755 /tmp/kubeseal "${BIN_DIR}/kubeseal"

SOPS_URL="$(curl -fsSL https://api.github.com/repos/getsops/sops/releases/latest | jq -r '.assets[] | select(.name | test("sops-v.*linux.amd64$")) | .browser_download_url' | head -n1)"
curl -fsSL "${SOPS_URL}" -o "${BIN_DIR}/sops"
chmod +x "${BIN_DIR}/sops"

AGE_URL="$(curl -fsSL https://api.github.com/repos/FiloSottile/age/releases/latest | jq -r '.assets[] | select(.name | test("age-v.*linux-amd64.tar.gz$")) | .browser_download_url' | head -n1)"
curl -fsSL "${AGE_URL}" -o /tmp/age.tar.gz
tar -xzf /tmp/age.tar.gz -C /tmp
install -m 0755 /tmp/age/age /tmp/age/age-keygen "${BIN_DIR}/"

curl -fsSL https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static -o "${BIN_DIR}/opa"
chmod +x "${BIN_DIR}/opa"

GITLEAKS_URL="$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest | jq -r '.assets[] | select(.name | test("gitleaks_.*linux_x64.tar.gz$")) | .browser_download_url' | head -n1)"
curl -fsSL "${GITLEAKS_URL}" -o /tmp/gitleaks.tar.gz
tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
install -m 0755 /tmp/gitleaks "${BIN_DIR}/gitleaks"

echo "[5/8] Installing GitHub CLI..."
if ! command -v gh >/dev/null 2>&1; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y gh
fi

echo "[6/8] Installing Python and Ruby security tools..."
pipx ensurepath
pipx install semgrep || pipx upgrade semgrep
pipx install sqlmap || pipx upgrade sqlmap
sudo gem install whatweb --no-document

echo "[7/8] Installing Go and recon tools..."
if ! command -v go >/dev/null 2>&1; then
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
fi
export PATH="${HOME}/go/bin:/usr/local/go/bin:${PATH}"
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/ffuf/ffuf/v2@latest
go install github.com/tomnomnom/assetfinder@latest
go install github.com/owasp-amass/amass/v5/cmd/amass@latest

echo "[8/8] Installing testssl.sh and preparing ZAP via Docker..."
if [ ! -d "${WORK_DIR}/testssl.sh" ]; then
  git clone --depth 1 https://github.com/drwetter/testssl.sh.git "${WORK_DIR}/testssl.sh"
else
  git -C "${WORK_DIR}/testssl.sh" pull --ff-only
fi
ln -sf "${WORK_DIR}/testssl.sh/testssl.sh" "${BIN_DIR}/testssl.sh"
docker pull ghcr.io/zaproxy/zaproxy:stable || true

echo
echo "Tool install complete. Log out and SSH back in so Docker group membership is active."
echo "Then run: scripts/create-ec2-kind-platform.sh"
