# EC2 Setup And Next Steps

Use this when running the assessment from an Ubuntu EC2 instance.

## 1. EC2 Requirements

- Ubuntu Server 22.04 LTS or 24.04 LTS.
- Recommended instance: `t3.xlarge` or better.
- Minimum workable instance: `t3.large`.
- Disk: 50 GB or more.
- Security group: SSH `22` from your IP only. Keep Kubernetes, ArgoCD, and app ports private unless you intentionally expose them for evidence.

## 2. Copy Or Clone The Repo

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
```

If the repo is already present:

```bash
cd YOUR_REPO
git pull
```

## 3. Install The Toolchain

```bash
chmod +x scripts/*.sh
./scripts/bootstrap-ec2-tools.sh
```

Log out and SSH back in after the script completes so Docker group membership applies.

Verify:

```bash
docker info
kubectl version --client
kind version
helm version
istioctl version --remote=false
argocd version --client
cosign version
trivy --version
gitleaks version
semgrep --version
syft version
grype version
kubeseal --version
sops --version
age --version
kyverno version
opa version
subfinder -version
amass -version
assetfinder --help
httpx -version
nuclei -version
ffuf -V
sqlmap --version
whatweb --version
testssl.sh --version
gh --version
```

## 4. Create The Local Kubernetes Platform

```bash
./scripts/create-ec2-kind-platform.sh
```

This creates a `kind` cluster and installs:

- NGINX Ingress
- Sealed Secrets
- Kyverno
- ArgoCD
- Istio

## 5. What Comes After Platform Setup

After the platform is ready, continue with:

```bash
kubectl get nodes
kubectl get pods -A
```

Then apply the task manifests and collect evidence:

```bash
kubectl apply -f task-1-workload-hardening/manifests
kubectl apply -f task-1-workload-hardening/policies
kubectl apply -f task-1-workload-hardening/secrets
kubectl apply -f task-3-istio-zero-trust/manifests
```

If any of those folders are missing, that means the manifests still need to be completed before final submission.

## 6. Important Scope Reminder

For Task 4, active testing is allowed only against the explicitly authorized vulnerable target or the bundled local vulnerable app. For `dodopayments.tech`, keep Part A passive only: CT logs, DNS, HTTP banners, and TLS posture.
