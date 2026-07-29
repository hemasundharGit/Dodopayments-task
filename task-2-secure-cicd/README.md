# Task 2 - Secure CI/CD For ledger-api

This folder contains the secure delivery pipeline and GitOps artifacts for `ledger-api`.

The GitHub Actions workflow lives at repo root:

```text
.github/workflows/ci-cd.yml
```

## Pipeline Stages

1. Checkout source.
2. Run Semgrep SAST and upload SARIF.
3. Run Gitleaks secrets scanning and upload SARIF.
4. Run Trivy filesystem/dependency scanning and upload SARIF.
5. Build the `ledger-api` container image.
6. Push the image to GHCR on non-PR runs.
7. Run Trivy image scanning and upload SARIF.
8. Sign the pushed image with Cosign keyless signing through GitHub OIDC.
9. Generate and attach SLSA-style provenance.
10. Upload scanner and provenance artifacts.

## Gate Policy At A Glance

| Gate | Blocks? |
| --- | --- |
| Semgrep high/critical-equivalent SAST finding | Yes |
| Gitleaks secret finding | Yes |
| Critical dependency CVE with fix available | Yes |
| Critical image CVE with fix available | Yes |
| Critical CVE with no fix available | Warn, time-boxed exception, tracking issue |
| Missing Cosign signature on release image | Yes |
| Missing provenance on release image | Yes |

Full policy:

```text
task-2-secure-cicd/docs/gate-policy.md
```

## GitHub UI Steps You Must Do

These require GitHub UI access and cannot be completed purely from local commands:

- Enable GitHub Actions if disabled.
- Enable code scanning/Security tab features for SARIF visibility.
- Ensure the workflow has permission to write packages and upload SARIF.
- For organization repos, allow GitHub Actions to create OIDC tokens.
- Confirm GHCR package visibility and access policy after the first push.
- Add `SEMGREP_APP_TOKEN` only if you want Semgrep Cloud features. The workflow can run without cloud publishing.

No stored Cosign private key is required. Signing uses GitHub OIDC keyless identity.

## Required Repo Assumptions

The workflow expects the application Docker context at:

```text
task-1-workload-hardening/ledger-api-assignment/app
```

If you move the app to repo root later, update `APP_CONTEXT` in `.github/workflows/ci-cd.yml`.

Because this assessment workspace intentionally cloned the original insecure repository, Gitleaks may detect the starter plaintext examples in `task-1-workload-hardening/ledger-api-assignment/deploy/deployment.yaml` until Task 1 removes or redacts those examples from the release branch. That is expected and desirable: the gate should fail when plaintext secrets are present anywhere in the repository.

The ArgoCD Application expects hardened Task 1 manifests at:

```text
task-1-workload-hardening/manifests
```

## ArgoCD

Application manifest:

```text
task-2-secure-cicd/argocd/application.yaml
```

Before applying it, replace:

```text
https://github.com/YOUR_ORG/YOUR_REPO.git
```

with your actual GitHub repository URL.

Install ArgoCD:

```powershell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
kubectl apply -f task-2-secure-cicd/argocd/application.yaml
```

## GitOps Drift Demo

Full demo:

```text
task-2-secure-cicd/docs/gitops-demo.md
```

Short version:

```powershell
argocd app sync ledger-workload-hardening
kubectl -n ledger scale deployment ledger-api --replicas=1
argocd app diff ledger-workload-hardening
argocd app sync ledger-workload-hardening
kubectl -n ledger get deployment ledger-api -o jsonpath="{.spec.replicas}"
```

Expected final replica count is the value committed in Git, not the manual live edit.

## Cosign Verification

After a successful non-PR workflow run, verify the image was signed by GitHub Actions OIDC:

```powershell
cosign verify `
  --certificate-oidc-issuer https://token.actions.githubusercontent.com `
  --certificate-identity-regexp "https://github.com/YOUR_ORG/YOUR_REPO/.github/workflows/ci-cd.yml@refs/heads/(main|master)" `
  ghcr.io/YOUR_ORG/ledger-api@sha256:IMAGE_DIGEST
```

Expected output excerpt:

```text
Verification for ghcr.io/YOUR_ORG/ledger-api@sha256:IMAGE_DIGEST --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted certificate authority certificates
```

Verify the SLSA-style attestation:

```powershell
cosign verify-attestation `
  --type slsaprovenance `
  --certificate-oidc-issuer https://token.actions.githubusercontent.com `
  --certificate-identity-regexp "https://github.com/YOUR_ORG/YOUR_REPO/.github/workflows/ci-cd.yml@refs/heads/(main|master)" `
  ghcr.io/YOUR_ORG/ledger-api@sha256:IMAGE_DIGEST
```

## Progressive Delivery Bonus

An Argo Rollouts canary example is included at:

```text
task-2-secure-cicd/rollouts/ledger-api-canary-rollout.yaml
```

Install Argo Rollouts locally:

```powershell
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl -n argo-rollouts rollout status deploy/argo-rollouts
```

This rollout is an alternative to the plain Deployment from Task 1. Do not apply both at the same time with the same selector unless you intentionally migrate from Deployment to Rollout.
