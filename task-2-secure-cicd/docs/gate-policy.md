# Secure Delivery Gate Policy

This policy defines which checks hard-block the `ledger-api` delivery pipeline and which checks warn while still producing evidence.

## Gate Summary

| Gate | Tool | Hard-blocks | Warn-only |
| --- | --- | --- | --- |
| SAST | Semgrep | High/critical-equivalent findings from the configured ruleset | Informational and low-confidence findings |
| Secret scanning | Gitleaks | Any detected secret | None |
| Dependency CVEs | Trivy filesystem scan | Critical CVEs with a fixed version available | Critical CVEs with no available fix |
| Image CVEs | Trivy image scan | Critical CVEs with a fixed version available | Critical CVEs with no available fix |
| Image integrity | Cosign | Missing keyless signature on release images | Pull request builds that do not push images |
| Provenance | Cosign attestation and GitHub artifact attestation | Missing attestation on release images | Pull request builds that do not push images |
| Security visibility | SARIF upload | Upload failure should be investigated, but scanner gate result is authoritative | Non-blocking upload retries may be allowed during GitHub outages |

## Semgrep SAST

Hard-block:

- Any high or critical-equivalent Semgrep result.
- In the workflow, Semgrep's blocking severity maps to rule severity `ERROR`.

Warn-only:

- Lower-severity findings are retained in SARIF and reviewed during normal remediation.

Rationale:

- High-confidence application flaws are cheap to fix before release and expensive to remediate after deployment.

## Gitleaks Secret Scanning

Hard-block:

- Any detected secret, credential, API token, private key, or password-like value.

Warn-only:

- None. Secret leaks are never warn-only.

Rationale:

- A leaked payment API key or database credential must be treated as compromised. The correct action is rotation and removal before merge.

## Trivy Dependency And Image CVEs

Hard-block:

- Critical vulnerabilities where Trivy reports a fixed version.

Warn-only:

- Critical vulnerabilities where no fixed version is available.

No-fix CVE policy:

- Create a tracking issue with package name, CVE, affected image or dependency, exposure analysis, and compensating controls.
- Assign an owner.
- Review the exception at least weekly.
- Remediate within 30 days of a fixed version becoming available.
- If the vulnerable component is internet-exposed, handles PAN, or has known active exploitation, security leadership can override this policy and block release even without a vendor fix.

Rationale:

- Blocking forever on a CVE with no fix can create delivery deadlock without reducing risk. A time-boxed exception with explicit ownership keeps risk visible.

## Cosign Keyless Signing

Hard-block:

- Release image cannot be signed with OIDC-backed Cosign keyless signing.
- Verification does not show the expected GitHub Actions identity.

Warn-only:

- Pull request builds do not push or sign images because untrusted fork PRs should not receive package write credentials.

Rationale:

- Keyless signing avoids long-lived signing keys while proving the image was produced by GitHub Actions for this repository.

## Provenance Attestation

Hard-block:

- Release image lacks an SLSA-style provenance attestation.

Warn-only:

- Pull request builds do not attach release attestations.

Rationale:

- Provenance links the produced image digest back to the repository, commit, workflow, and run that built it.

## SARIF Upload

All scanners emit SARIF for GitHub's Security tab:

- Semgrep: SAST
- Trivy filesystem: dependencies and repository files
- Trivy image: built container image
- Gitleaks: secrets

The scanner's gate decision is authoritative. SARIF upload is evidence and triage support.
