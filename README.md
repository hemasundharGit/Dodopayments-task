# Dodo Payments — DevSecOps Technical Assessment

This repo contains my submission for the Dodo Payments Security & DevOps
Engineer technical assessment: hardening `ledger-api` end to end across
workload security, secure delivery, zero-trust networking, and offensive
security.

Everything runs on a **local Kubernetes cluster (kind)** with free tooling —
no cloud account required, per the assessment's constraints.

## Repo structure

| Folder | Task | Status |
|---|---|---|
| [`task-1-workload-hardening/`](./task-1-workload-hardening) | Deploy & harden the workload | See task README |
| [`task-2-secure-cicd/`](./task-2-secure-cicd) + [`.github/workflows/`](./.github/workflows) | Secure CI/CD & supply chain | See task README |
| [`task-3-istio-zero-trust/`](./task-3-istio-zero-trust) | Service mesh & zero-trust (Istio) | See task README |
| [`task-4-recon-pentest/part-a-recon/`](./task-4-recon-pentest/part-a-recon) | Recon (passive OSINT) | See task README |
| `task-4-recon-pentest/part-b-pentest/` | Penetration test (authorized target) | In progress |
| [`ledger-api-assignment/`](./ledger-api-assignment) | Target application (as provided) | Vendored from assignment repo |
| [`scripts/`](./scripts) | Local environment bootstrap (Windows/PowerShell) | Installs CLIs + spins up kind cluster with Ingress, Sealed Secrets, Kyverno, ArgoCD, Istio |
| [`LOCAL-SETUP-AND-RUNBOOK.md`](./LOCAL-SETUP-AND-RUNBOOK.md) | Setup + evidence-collection checklist | Step-by-step for every task |

## How to reproduce locally

1. Start Docker Desktop.
2. From repo root, install required CLIs:
   ```
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\scripts\install-windows-tools.ps1
   ```
3. Bring up the local platform (kind cluster + Ingress + Sealed Secrets +
   Kyverno + ArgoCD + Istio):
   ```
   .\scripts\create-local-kind-platform.ps1
   ```
4. Follow [`LOCAL-SETUP-AND-RUNBOOK.md`](./LOCAL-SETUP-AND-RUNBOOK.md) for the
   exact verification commands and expected output for each task.

Full CLI list and manual/GUI steps (Docker Desktop start, GitHub Actions +
Security tab enablement) are documented in the runbook.

## Task summaries

### Task 1 — Deploy & Harden the Workload
`ledger-api` plus a neighbour service, deployed with a locked-down
`securityContext` (non-root, read-only root filesystem, all capabilities
dropped, seccomp `RuntimeDefault`), resource requests/limits and health
probes on every container, a dedicated least-privilege ServiceAccount per
workload, secrets migrated out of git via Sealed Secrets, and Kyverno
ClusterPolicies rejecting root containers, `:latest` tags, and unsigned
images. See [task README](./task-1-workload-hardening) for the full
rationale and verification steps.

### Task 2 — Secure CI/CD Pipeline & Supply Chain
GitHub Actions pipeline (build → Semgrep SAST → Trivy/Grype CVE scan →
gitleaks secrets scan → Cosign keyless signing → SLSA-style provenance →
GHCR push), with scan results surfaced as SARIF in the repo's Security tab.
ArgoCD as GitOps source of truth, with drift detection and self-heal
demonstrated against a manual `kubectl` edit. Gate policy (what hard-blocks
vs. warns, and the stance on unfixed CVEs) is documented in the task README.

### Task 3 — Service Mesh & Zero-Trust (Istio)
Istio installed with sidecar injection for the `ledger` namespace, mTLS
enforced `STRICT` via `PeerAuthentication`, a default-deny
`AuthorizationPolicy` with explicit allows keyed on workload identity
(SPIFFE / ServiceAccount, not IP), and a `NetworkPolicy` layered underneath
for defense-in-depth. Verification proves an unauthorized caller is blocked
(`403`) and the authorized neighbour is allowed (`200`).

### Task 4 — Reconnaissance & Penetration Testing
**Part A (passive):** subdomain enumeration and TLS/tech fingerprinting
against `dodopayments.tech` using only public data (crt.sh, subfinder,
amass, httpx, whatweb, testssl.sh) — no active scanning against production
hosts.
**Part B (active):** OWASP Top 10-class testing against the designated
authorized target only, reported with CVSS v3.1 scoring, reproduction
steps, and remediation per finding.

## What's unfinished / known gaps

Being upfront here rather than overstating completeness:

- Task 1 manifests/policies/secrets need to be fully populated and applied
  against a live cluster with evidence captured (see runbook §4).
- Task 4 Part B report is not yet written up.
- End-to-end evidence (screenshots, pipeline run link, cosign verify output,
  ArgoCD diff/sync output, Istio proof) still needs to be collected by
  running the runbook against a live cluster.

With more time, the next priorities would be: finish Task 1 evidence
collection, run the CI/CD pipeline end to end and capture the SARIF/signing
proof, and complete the Part B pentest against the local `ledger-api`
target.

## Evaluation mapping

| Assessment criterion | Where it's addressed |
|---|---|
| Security Hardening | Task 1 |
| Zero-Trust & Networking | Task 3 |
| Secure Delivery | Task 2 |
| Offensive Skill | Task 4 |
| Automation & Quality | `scripts/`, CI workflow, reproducibility of runbook |
| Judgement | Design-decision rationale in each task README |
