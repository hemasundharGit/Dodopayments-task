# GitOps Drift And Self-Heal Demo

This demo uses a local kind cluster and ArgoCD. It assumes Task 1 hardened manifests exist at:

```text
task-1-workload-hardening/manifests
```

The ArgoCD `Application` in `task-2-secure-cicd/argocd/application.yaml` points to that path as the source of truth.

## Install ArgoCD

```powershell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
kubectl -n argocd rollout status deploy/argocd-repo-server
kubectl -n argocd rollout status deploy/argocd-application-controller
```

Expected output:

```text
namespace/argocd created
...
deployment "argocd-server" successfully rolled out
deployment "argocd-repo-server" successfully rolled out
deployment "argocd-application-controller" successfully rolled out
```

## Install ArgoCD CLI

Windows with Chocolatey:

```powershell
choco install argocd-cli -y
```

Or download from:

```text
https://github.com/argoproj/argo-cd/releases
```

## Update The Application Repo URL

Edit:

```text
task-2-secure-cicd/argocd/application.yaml
```

Replace:

```text
https://github.com/YOUR_ORG/YOUR_REPO.git
```

with the GitHub repository URL that contains `task-1-workload-hardening/manifests`.

## Apply The Application

```powershell
kubectl apply -f task-2-secure-cicd/argocd/application.yaml
```

Expected output:

```text
application.argoproj.io/ledger-workload-hardening created
```

## Log In To ArgoCD

Port-forward:

```powershell
kubectl -n argocd port-forward svc/argocd-server 8081:443
```

In another shell:

```powershell
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | %{ [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }
argocd login localhost:8081 --username admin --password $password --insecure
```

Expected output:

```text
'admin:login' logged in successfully
Context 'localhost:8081' updated
```

## Initial Sync

```powershell
argocd app get ledger-workload-hardening
argocd app sync ledger-workload-hardening
argocd app wait ledger-workload-hardening --health --sync
```

Expected output:

```text
Name:               argocd/ledger-workload-hardening
Sync Status:        Synced to main (...)
Health Status:      Healthy
```

## Create Manual Drift

Change the live Deployment without changing Git:

```powershell
kubectl -n ledger scale deployment ledger-api --replicas=1
kubectl -n ledger get deployment ledger-api -o jsonpath="{.spec.replicas}"
```

Expected output:

```text
deployment.apps/ledger-api scaled
1
```

## Show ArgoCD Detects Drift

```powershell
argocd app get ledger-workload-hardening
argocd app diff ledger-workload-hardening
```

Expected output excerpt:

```text
Sync Status:        OutOfSync from main (...)

===== apps/Deployment ledger/ledger-api ======
...
-  replicas: 3
+  replicas: 1
```

Depending on your ArgoCD version, the `+` and `-` direction may be reversed. The important evidence is that the live replica count differs from Git.

## Show Self-Heal

The Application enables:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

Wait for self-heal or force a sync:

```powershell
argocd app sync ledger-workload-hardening
argocd app wait ledger-workload-hardening --health --sync
kubectl -n ledger get deployment ledger-api -o jsonpath="{.spec.replicas}"
argocd app get ledger-workload-hardening
```

Expected output:

```text
deployment.apps/ledger-api configured
3
Sync Status:        Synced to main (...)
Health Status:      Healthy
```

## Notes

- The demo requires a GitHub repository reachable by the local ArgoCD controller.
- If the repository is private, add repository credentials to ArgoCD before applying the Application.
- If Task 1 manifests are not yet complete, ArgoCD will report sync errors. That is expected until the hardened YAML exists in `task-1-workload-hardening/manifests`.
