# Defense In Depth: Istio Policy Plus NetworkPolicy

This task uses both Istio AuthorizationPolicy and Kubernetes NetworkPolicy because they catch different failure modes.

## What Istio AuthorizationPolicy Catches

Istio AuthorizationPolicy operates at the service identity and request layer.

It can enforce:

- Source workload identity using SPIFFE principals.
- ServiceAccount-based authorization.
- HTTP methods.
- HTTP paths.
- Destination ports.
- Namespace-level default deny.

Example:

```yaml
source.principals:
  - cluster.local/ns/ledger/sa/ledger-neighbour
```

This means `ledger-api` accepts requests from the `ledger-neighbour` ServiceAccount, not from a pod IP.

That matters because pod IPs are ephemeral and spoofable as an authorization model. ServiceAccount identity is the better zero-trust primitive.

## What NetworkPolicy Catches

Kubernetes NetworkPolicy operates at the network layer.

It can reduce blast radius if:

- A pod is compromised and tries to scan the namespace.
- A pod is accidentally deployed without an Istio sidecar.
- A workload attempts mesh bypass by calling pod IPs directly.
- A non-HTTP protocol is used where Istio HTTP path rules do not apply.
- An operator accidentally weakens an Istio AuthorizationPolicy.

NetworkPolicy also helps document PCI segmentation boundaries by making default network reachability explicit.

## What NetworkPolicy Does Not Catch

NetworkPolicy does not understand:

- SPIFFE identity.
- Kubernetes ServiceAccount identity as cryptographic workload identity.
- HTTP methods.
- HTTP paths.
- JWT claims.
- mTLS certificate identity.

It can usually say "pod label A can reach pod label B on port 8080", but it cannot prove that the caller is `cluster.local/ns/ledger/sa/ledger-neighbour`.

## What Istio Does Not Fully Replace

Istio is strong for meshed traffic, but NetworkPolicy still matters because:

- Not every pod may be injected correctly.
- An attacker may try direct pod-IP traffic.
- Some CNIs enforce NetworkPolicy before traffic reaches Envoy.
- A namespace default-deny at L3/L4 is a useful backstop during policy mistakes.

## Layered Result

The intended policy stack is:

1. Kubernetes namespace isolates the workload boundary.
2. Pod Security Standards prevent privileged or unsafe pods.
3. NetworkPolicy denies default ingress and egress.
4. Istio STRICT mTLS rejects plaintext peer traffic.
5. Istio AuthorizationPolicy allows only named SPIFFE identities.

For a PCI workload, this gives both network segmentation and authenticated service-to-service authorization.
