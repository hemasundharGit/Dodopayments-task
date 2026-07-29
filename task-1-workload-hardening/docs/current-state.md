# Current State Assessment

Assessment target: `https://github.com/bhabani-dodo/ledger-api-assignment`

Local clone path: `task-1-workload-hardening/ledger-api-assignment`

Namespace in starter manifests: `payments`

Target namespace for hardened deliverables: `ledger`

## Source Layout Observed

```text
README.md
app/
  Dockerfile
  app.py
  requirements.txt
deploy/
  deployment.yaml
  neighbour.yaml
  namespace.yaml
  service.yaml
```

## Application Behavior

The service is a Flask API listening on `0.0.0.0:8080`.

Observed endpoints from `app/app.py`:

- `GET /health`: returns `{"status": "ok"}`. This is suitable for Kubernetes liveness and readiness probes.
- `POST /tokenize`: accepts a PAN and returns a deterministic token and last four digits.
- `GET /transactions`: returns sample transaction data.
- `POST /import`: imports a YAML blob.
- `GET /fetch?url=`: fetches a caller-supplied URL.

## Container Image Findings

File: `app/Dockerfile`

```dockerfile
FROM python:3.6-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080

CMD ["python", "app.py"]
```

Findings:

- The image uses `python:3.6-slim`, which is end-of-life and inappropriate for a production or PCI-DSS-adjacent workload.
- No non-root user is created.
- No `USER` instruction is present, so the container runs as root by default.
- The image does not pin the base image by digest.
- The image does not include runtime hardening such as a dedicated UID/GID.

## Dependency Findings

File: `app/requirements.txt`

```text
Flask==0.12.2
Werkzeug==0.14.1
PyYAML==5.1
requests==2.19.1
Jinja2==2.10
```

Findings:

- The Python dependencies are very old and likely contain known vulnerabilities.
- This assessment focuses on Kubernetes workload hardening, but a production remediation should upgrade and scan dependencies.

## Application Security Findings

File: `app/app.py`

Findings:

- `yaml.load(request.data)` is unsafe because it can deserialize attacker-controlled YAML. It should be changed to `yaml.safe_load(...)`.
- `/fetch?url=` accepts an arbitrary user-controlled URL and performs a server-side request. This is an SSRF risk unless restricted to an allowlist or removed.
- The sample transaction data includes full PAN-like values in memory and in API responses. PCI-DSS-appropriate behavior should avoid storing or returning full PAN unless strictly required and protected.
- Tokenization uses unsalted SHA-256 truncation. This is deterministic and unsuitable as a real PAN tokenization scheme.
- Secrets are read from environment variables, which is acceptable for Kubernetes Secret injection, but the starter manifest injects those values as plaintext literals.

## Starter Kubernetes Manifest Findings

File: `deploy/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: payments
```

Findings:

- No Pod Security Standards labels are applied.
- The hardened deliverable will use namespace `ledger` and enforce `restricted`.

File: `deploy/deployment.yaml`

Findings:

- Plaintext secrets are committed directly in the Deployment:
  - `STRIPE_API_KEY="sk_live_9f3a2b7c1e4d8REDACTED"`
  - `DB_PASSWORD="P@ssw0rd123"`
- No dedicated `serviceAccountName` is set, so pods use the namespace default ServiceAccount.
- No `automountServiceAccountToken: false`; pods may receive Kubernetes API tokens unnecessarily.
- No pod-level or container-level `securityContext`.
- No `runAsNonRoot`.
- No non-zero `runAsUser`.
- No `readOnlyRootFilesystem`.
- Linux capabilities are not dropped.
- `allowPrivilegeEscalation` is not disabled.
- No `seccompProfile`.
- No resource requests or limits.
- No readiness probe.
- No liveness probe.
- Image is mutable by tag: `ledger-api:starter`.
- Image is not referenced by digest.
- Image signature is not enforced.

File: `deploy/service.yaml`

Findings:

- Service is basic and acceptable as a starting point.
- No Ingress is provided.
- No NetworkPolicy is provided. This was not explicitly required, but would be recommended for production PCI-DSS segmentation.

File: `deploy/neighbour.yaml`

Findings:

- A separate `reporting` ServiceAccount exists, but no Role or RoleBinding defines least privilege.
- The neighbour Deployment has no security context.
- No resource requests or limits.
- No liveness or readiness probes.
- Uses `sleep infinity`, which is acceptable only as a demo client, not a production neighbour service.
- No Service, ConfigMap, or Ingress exists for the neighbour.

## Secrets Before/After Plan

Current plaintext secrets exist in `deploy/deployment.yaml`.

The hardened manifests will remove plaintext secret values from all apply-able Kubernetes manifests and use Sealed Secrets:

- Plaintext secret will be generated locally only as a temporary input to `kubeseal`.
- The temporary plaintext file will not be committed.
- The committed artifact will be a `SealedSecret` under `secrets/`.
- `ledger-api` will consume the resulting Kubernetes Secret with `envFrom.secretRef`.

Note: this repository already contains plaintext secrets in the original upstream history. For this task's deliverable, the plaintext key must be absent from the new hardened manifests. Rewriting the upstream Git history is out of scope unless explicitly requested.

## RBAC Assumption

The Flask app does not call the Kubernetes API. The neighbour service also does not need Kubernetes API access.

Therefore, each Deployment should use a dedicated ServiceAccount with:

- `automountServiceAccountToken: false`
- An empty Role
- A RoleBinding to that empty Role, documenting intentional zero Kubernetes API privileges

This is more least-privilege than granting read access only to prove RBAC exists.

## Probe Assumption

No change is needed to add a health endpoint because `GET /health` already exists in `app/app.py`.

The hardened `ledger-api` Deployment should use:

- Readiness: `GET /health` on port `8080`
- Liveness: `GET /health` on port `8080`

For the neighbour service, the hardened deliverable will use a lightweight HTTP echo service that exposes an HTTP port suitable for TCP or HTTP probes.

## Policy Guardrail Plan

Kyverno policies will be created to reject:

- Pods that do not set `runAsNonRoot: true`.
- Pods using `:latest`.
- Pods using an image with no explicit tag or digest.
- Unsigned images, using a stubbed `verifyImages` policy with clear TODO wiring if no signed Task 2 image exists yet.

The original insecure manifest should be rejected once these policies are active because it:

- Has no `runAsNonRoot: true`.
- Does not use the hardened security context.
- Uses plaintext secrets.
- Uses an image tag rather than an immutable signed digest.

## PCI-DSS-Relevant Gaps

The starter workload is not production-grade for a payments environment because it lacks:

- Secret management outside Git.
- Workload identity least privilege.
- Runtime hardening.
- Admission controls.
- Pod Security Standards.
- Immutable or signed images.
- Resource governance.
- Health checking.
- Clear ingress controls.
- PAN-safe application behavior.
- Dependency freshness and vulnerability management.
