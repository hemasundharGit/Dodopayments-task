# Certificates And Trust

## Workload Identity

Istio gives each meshed workload a SPIFFE identity based on:

- Kubernetes namespace
- Kubernetes ServiceAccount
- Trust domain

For this assessment, the assumed identities are:

```text
spiffe://cluster.local/ns/ledger/sa/ledger-api
spiffe://cluster.local/ns/ledger/sa/ledger-neighbour
spiffe://cluster.local/ns/ledger/sa/unauthorized-curl
```

Istio AuthorizationPolicy uses the shortened principal form:

```text
cluster.local/ns/ledger/sa/ledger-api
cluster.local/ns/ledger/sa/ledger-neighbour
cluster.local/ns/ledger/sa/unauthorized-curl
```

## How Certificates Are Issued

Each workload pod receives an Envoy sidecar. The sidecar contacts `istiod` over the xDS/SDS control-plane channel and requests a workload certificate for the pod's ServiceAccount identity.

The issuing flow is:

1. Pod starts with an injected Istio sidecar.
2. Envoy proves the pod's Kubernetes identity to `istiod`.
3. `istiod` acts as the mesh Certificate Authority.
4. `istiod` issues a short-lived X.509 SVID certificate containing the workload SPIFFE identity.
5. Envoy stores the certificate in memory and uses it for mutual TLS between workloads.

The application container does not need to load private keys or certificates. Envoy terminates and originates mTLS transparently.

## Rotation

Istio workload certificates are short-lived and automatically rotated by the sidecar through SDS before expiry.

Operationally:

- Envoy keeps certificates in memory.
- `istiod` pushes or serves updated cert material through SDS.
- Rotation does not require pod restarts in normal operation.
- If `istiod` is unavailable, existing connections and currently valid certificates continue until expiry, but new issuance/rotation can fail.

The exact workload certificate lifetime is controlled by Istio mesh configuration. For a local assessment cluster, the default Istio lifetime is acceptable for demonstration. For production PCI workloads, keep certificates short-lived and monitor rotation failures.

Useful commands:

```powershell
istioctl proxy-config secret deploy/ledger-api -n ledger
istioctl proxy-config secret deploy/ledger-neighbour -n ledger
```

Expected evidence:

```text
RESOURCE NAME     TYPE           STATUS     VALID CERT     SERIAL NUMBER
default           Cert Chain     ACTIVE     true           ...
ROOTCA            CA             ACTIVE     true           ...
```

## Trust Root Choice

For this local kind assessment, the manifests assume Istio's default self-signed `istiod` root CA.

This is acceptable for local proof because:

- It requires no cloud account or external PKI.
- It demonstrates workload identity, mTLS, AuthorizationPolicy, and certificate rotation.
- The trust boundary is intentionally the local mesh.

For a PCI production environment, I would reject a long-lived standalone self-signed mesh root as the final design. I would instead plug Istio into an externally governed private PKI root or intermediate CA with:

- HSM-backed or centrally managed root key material.
- Formal certificate policy and audit trail.
- Root/intermediate rotation procedures.
- Separation between platform operators and CA administrators.
- Monitoring for CA health and issuance anomalies.

The practical production pattern is:

- Offline or tightly controlled enterprise root CA.
- Istio intermediate CA per cluster or environment.
- `istiod` uses that intermediate to issue workload certificates.

That keeps the mesh operationally simple while making the PCI trust root auditable and centrally governed.
