# PCI CDE Scope Reasoning

The `ledger` namespace is treated as the local assessment's Cardholder Data Environment boundary because it contains:

- `ledger-api`, which processes PAN-like input through `/tokenize`.
- Transaction endpoints that currently return PAN-like sample data.
- Secrets needed by the payment workload.
- The neighbour service that is allowed to call `ledger-api`.

## Scope Boundary

In this design, PCI-relevant scope is centered on:

```text
namespace: ledger
service accounts:
  ledger-api
  ledger-neighbour
secrets:
  ledger-api-secrets
services:
  ledger-api
  ledger-neighbour
```

The mesh identity boundary is:

```text
cluster.local/ns/ledger/sa/*
```

Only explicitly allowed identities can communicate with the payment API.

## Scope Reduction Controls

The following controls reduce accidental scope expansion:

- Namespace-level Istio STRICT mTLS.
- Namespace default-deny AuthorizationPolicy.
- Authorization keyed on SPIFFE identity, not IP address.
- Kubernetes NetworkPolicy default-deny ingress and egress.
- Pod Security Standards `restricted`.
- Dedicated ServiceAccounts per workload.
- No default ServiceAccount use.

## What Is Out Of Scope

Workloads outside `ledger` should be out of CDE scope only if they cannot:

- Connect to `ledger-api`.
- Read `ledger` Secrets.
- Impersonate `ledger` ServiceAccounts.
- Deploy into the `ledger` namespace.
- Modify Istio or NetworkPolicy controls.

This means platform admin roles, CI/CD deploy credentials, ArgoCD, and Istio control plane permissions may still be security-impacting even if they are not payment application workloads.

## PCI Production Note

For production, namespace segmentation alone is not enough. I would pair this with:

- Separate clusters or node pools for PCI workloads where required by risk assessment.
- External CA-backed Istio trust root.
- Strong admission controls.
- Audit logging for Kubernetes, Istio, and CI/CD.
- Egress allowlisting for payment processor endpoints.
- Tokenization that never stores or returns full PAN in application responses.
