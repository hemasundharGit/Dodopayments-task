# Local Setup And Assessment Runbook

This runbook is the checklist to install tools, run the local cluster, verify controls, and collect evidence for the Dodo Payments DevSecOps assessment.

## 0. What Was Verified From The PDF

The PDF requires four folders/tasks:

- Task 1: Kubernetes workload hardening for `ledger-api`.
- Task 2: secure CI/CD, GHCR, security gates, Cosign, provenance, GitOps.
- Task 3: Istio mesh, mTLS STRICT, identity-based AuthorizationPolicy, NetworkPolicy.
- Task 4: passive OSINT plus active pentest only against an authorized target.

It also requires:

- Public GitHub repository.
- One README per task.
- Screenshots, terminal output, pipeline links, or recordings proving controls work.
- Top-level README linking all tasks.
- No cloud account required.

## 1. Start Docker Desktop

Docker Desktop is installed, but in this shell the daemon was not running:

```text
error during connect: open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified
```

Do this manually:

1. Open Docker Desktop.
2. Wait until it says Docker is running.
3. Run:

```powershell
docker version
```

Expected:

```text
Client: ...
Server: ...
```

## 2. Install CLI Requirements

From repo root:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\install-windows-tools.ps1
```

If Go is newly installed, close and reopen PowerShell, then run:

```powershell
.\scripts\install-windows-tools.ps1
```

Minimum required CLIs:

```text
git
docker
kubectl
kind
helm
cosign
kubeseal
kyverno
istioctl
argocd
semgrep
trivy
gitleaks
subfinder
amass
assetfinder
httpx
whatweb
testssl.sh
nuclei
ffuf
sqlmap
```

Manual/GUI tools:

- Docker Desktop must be started manually.
- GitHub Actions and Security tab must be enabled in GitHub UI.
- OWASP ZAP or Burp Community can be installed manually for screenshots and proxy testing.
- `whatweb` and `testssl.sh` are easiest in WSL/Ubuntu.

## 3. Create Local Cluster And Install Platform Add-ons

After Docker is running:

```powershell
.\scripts\create-local-kind-platform.ps1
```

This installs:

- kind cluster named `kind`
- NGINX Ingress
- Sealed Secrets controller
- Kyverno
- ArgoCD
- Istio demo profile

Verify:

```powershell
kubectl config current-context
kubectl get nodes
kubectl get pods -A
```

Expected:

```text
kind-kind
NAME                 STATUS   ROLES
kind-control-plane   Ready    control-plane
```

## 4. Task 1 Evidence To Collect

Folder:

```text
task-1-workload-hardening/
```

Current completed doc:

```text
task-1-workload-hardening/docs/current-state.md
```

You still need the hardened manifests fully populated before final submission if you want a complete showcase:

```text
task-1-workload-hardening/manifests/
task-1-workload-hardening/policies/
task-1-workload-hardening/secrets/
```

Verification commands once manifests exist:

```powershell
kubectl apply -f task-1-workload-hardening\manifests
kubectl apply -f task-1-workload-hardening\policies
kubectl apply -f task-1-workload-hardening\secrets
kubectl -n ledger get deploy,pods,svc,ingress
kubectl -n ledger describe pod -l app.kubernetes.io/name=ledger-api
kubectl -n ledger auth can-i --as=system:serviceaccount:ledger:ledger-api list secrets
kubectl get clusterpolicy
kubectl -n ledger get sealedsecret
```

Evidence screenshots:

- Hardened pod has `istio-proxy` only after Task 3 injection.
- Pod security context shows non-root, dropped capabilities, read-only filesystem.
- Kyverno rejects insecure deployment.
- SealedSecret exists; plaintext Secret file is absent.

## 5. Task 2 Evidence To Collect

Files:

```text
.github/workflows/ci-cd.yml
task-2-secure-cicd/
```

GitHub UI steps:

- Push repo to public GitHub.
- Enable GitHub Actions.
- Enable code scanning/Security tab.
- Confirm GHCR package permissions.

After a workflow run, collect:

- GitHub Actions run URL.
- SARIF/code scanning screenshots.
- GHCR image digest.
- Cosign verification output:

```powershell
cosign verify `
  --certificate-oidc-issuer https://token.actions.githubusercontent.com `
  --certificate-identity-regexp "https://github.com/YOUR_ORG/YOUR_REPO/.github/workflows/ci-cd.yml@refs/heads/(main|master)" `
  ghcr.io/YOUR_ORG/ledger-api@sha256:IMAGE_DIGEST
```

GitOps demo:

```powershell
kubectl apply -f task-2-secure-cicd\argocd\application.yaml
argocd app sync ledger-workload-hardening
kubectl -n ledger scale deployment ledger-api --replicas=1
argocd app diff ledger-workload-hardening
argocd app sync ledger-workload-hardening
```

## 6. Task 3 Evidence To Collect

Folder:

```text
task-3-istio-zero-trust/
```

Run:

```powershell
kubectl apply -f task-3-istio-zero-trust\manifests\00-namespace-injection.yaml
kubectl -n ledger rollout restart deployment/ledger-api
kubectl -n ledger rollout restart deployment/ledger-neighbour
kubectl apply -f task-3-istio-zero-trust\manifests\10-peer-authentication-strict.yaml
kubectl apply -f task-3-istio-zero-trust\manifests\20-authorization-policies.yaml
kubectl apply -f task-3-istio-zero-trust\manifests\40-network-policies.yaml
```

Verify mTLS:

```powershell
istioctl authn tls-check deploy/ledger-neighbour.ledger ledger-api.ledger.svc.cluster.local
```

Expected proof:

```text
SERVER STRICT
CLIENT ISTIO_MUTUAL
```

Unauthorized caller:

```powershell
kubectl apply -f task-3-istio-zero-trust\manifests\30-unauthorized-curl.yaml
kubectl -n ledger logs job/unauthorized-curl
```

Expected:

```text
HTTP/1.1 403 Forbidden
RBAC: access denied
```

Authorized neighbour:

```powershell
$POD = kubectl -n ledger get pod -l app.kubernetes.io/name=ledger-neighbour -o jsonpath="{.items[0].metadata.name}"
kubectl -n ledger exec $POD -c ledger-neighbour -- curl -sS -i http://ledger-api.ledger.svc.cluster.local:8080/health
```

Expected:

```text
HTTP/1.1 200 OK
{"status":"ok"}
```

## 7. Task 4 Part A Evidence To Collect

Folder:

```text
task-4-recon-pentest/part-a-recon/
```

Use the commands in:

```text
task-4-recon-pentest/part-a-recon/README.md
```

Important scope:

- Passive public data only.
- No exploitation, fuzzing, brute forcing, or active scanners against `dodopayments.tech`.

Save output in:

```text
task-4-recon-pentest/part-a-recon/outputs/
```

Then update:

```text
task-4-recon-pentest/part-a-recon/docs/attack-surface-report.md
```

## 8. Task 4 Part B Evidence To Collect

You must choose exactly one authorized active target:

- The lab host from your invite, or
- The local vulnerable `ledger-api` app.

Do not run active tests against any other Dodo host.

For local app:

```powershell
cd task-1-workload-hardening\ledger-api-assignment\app
python -m pip install -r requirements.txt
python app.py
```

Target:

```text
http://localhost:8080
```

Tools to run yourself:

- Burp Community or OWASP ZAP for manual proxy testing.
- nuclei with rate limits.
- ffuf with low rate limits.
- sqlmap only against confirmed test parameters and with low risk/level.

Report output should go to:

```text
task-4-recon-pentest/part-b-pentest/docs/pentest-report.md
```

## 9. Final Submission Checklist

Before sharing the GitHub repo:

```powershell
git status
git diff --check
```

Make sure you have:

- Top-level README.
- README per task.
- Screenshots or terminal logs for Tasks 1-4.
- Pipeline run link.
- Cosign verify output.
- ArgoCD drift/self-heal proof.
- Istio mTLS and AuthorizationPolicy proof.
- Recon report.
- Pentest report.
- Clear notes on anything unfinished and what you would do next.
