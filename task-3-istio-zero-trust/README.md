# Task 3 - Istio Zero Trust For ledger-api

This folder brings `ledger-api` and its neighbour into an Istio mesh with enforced zero-trust controls.

## Assumptions

Task 1 should provide workloads in namespace `ledger` with these names and ServiceAccounts:

| Workload | Service | ServiceAccount | Label |
| --- | --- | --- | --- |
| ledger-api | `ledger-api` | `ledger-api` | `app.kubernetes.io/name: ledger-api` |
| neighbour | `ledger-neighbour` | `ledger-neighbour` | `app.kubernetes.io/name: ledger-neighbour` |

If your Task 1 manifests use `app: ledger-api` instead of `app.kubernetes.io/name: ledger-api`, update the selectors in:

```text
task-3-istio-zero-trust/manifests/20-authorization-policies.yaml
task-3-istio-zero-trust/manifests/40-network-policies.yaml
```

## Install Istio Locally

Run this from your machine against the kind cluster:

```powershell
kubectl config use-context kind-kind
istioctl install --set profile=demo -y
kubectl -n istio-system rollout status deployment/istiod
kubectl -n istio-system rollout status deployment/istio-ingressgateway
```

The `demo` profile is intentionally chosen for a local assessment because it installs the control plane and ingress gateway with reasonable defaults. For production, use an explicitly reviewed `IstioOperator` configuration with resource sizing, revisioned upgrades, external CA integration, and telemetry settings.

## Enable Sidecar Injection

Apply the namespace manifest:

```powershell
kubectl apply -f task-3-istio-zero-trust/manifests/00-namespace-injection.yaml
```

Or label an existing namespace directly:

```powershell
kubectl label namespace ledger istio-injection=enabled --overwrite
kubectl label namespace ledger pod-security.kubernetes.io/enforce=restricted --overwrite
kubectl label namespace ledger pod-security.kubernetes.io/audit=restricted --overwrite
kubectl label namespace ledger pod-security.kubernetes.io/warn=restricted --overwrite
```

Restart workloads so sidecars are injected:

```powershell
kubectl -n ledger rollout restart deployment/ledger-api
kubectl -n ledger rollout restart deployment/ledger-neighbour
kubectl -n ledger rollout status deployment/ledger-api
kubectl -n ledger rollout status deployment/ledger-neighbour
```

Verify injection:

```powershell
kubectl -n ledger get pods -o jsonpath="{range .items[*]}{.metadata.name}{': '}{range .spec.containers[*]}{.name}{' '}{end}{'\n'}{end}"
```

Expected output includes `istio-proxy` in each application pod:

```text
ledger-api-...: ledger-api istio-proxy
ledger-neighbour-...: ledger-neighbour istio-proxy
```

## Apply Zero-Trust Manifests

```powershell
kubectl apply -f task-3-istio-zero-trust/manifests/10-peer-authentication-strict.yaml
kubectl apply -f task-3-istio-zero-trust/manifests/20-authorization-policies.yaml
kubectl apply -f task-3-istio-zero-trust/manifests/40-network-policies.yaml
```

## Prove mTLS STRICT

Check mTLS status:

```powershell
istioctl authn tls-check deploy/ledger-neighbour.ledger ledger-api.ledger.svc.cluster.local
```

Expected proof:

```text
HOST:PORT                                  STATUS     SERVER     CLIENT
ledger-api.ledger.svc.cluster.local:8080  OK         STRICT     ISTIO_MUTUAL
```

Exact formatting varies by Istio version. The important evidence is `SERVER STRICT` and client mode `ISTIO_MUTUAL`.

## Plaintext Pod-IP Bypass Test

This test bypasses the client sidecar by starting a pod with injection disabled, then curling the `ledger-api` pod IP directly. STRICT mTLS should refuse plaintext.

```powershell
$LEDGER_API_POD = kubectl -n ledger get pod -l app.kubernetes.io/name=ledger-api -o jsonpath="{.items[0].metadata.name}"
$LEDGER_API_IP = kubectl -n ledger get pod $LEDGER_API_POD -o jsonpath="{.status.podIP}"
kubectl -n ledger run plaintext-curl `
  --image=curlimages/curl:8.8.0 `
  --restart=Never `
  --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"false"},"labels":{"app.kubernetes.io/name":"plaintext-curl"}},"spec":{"serviceAccountName":"unauthorized-curl","automountServiceAccountToken":false,"securityContext":{"runAsNonRoot":true,"runAsUser":10001,"runAsGroup":10001,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"plaintext-curl","image":"curlimages/curl:8.8.0","command":["sh","-c","curl -sv --max-time 5 http://'$LEDGER_API_IP':8080/health"],"securityContext":{"allowPrivilegeEscalation":false,"readOnlyRootFilesystem":true,"capabilities":{"drop":["ALL"]}},"resources":{"requests":{"cpu":"25m","memory":"32Mi"},"limits":{"cpu":"100m","memory":"64Mi"}}}]}}'
kubectl -n ledger logs pod/plaintext-curl
kubectl -n ledger delete pod plaintext-curl --ignore-not-found
```

Expected output:

```text
* Connected to ... port 8080
> GET /health HTTP/1.1
...
curl: (52) Empty reply from server
```

Depending on timing and CNI behavior, you may see:

```text
curl: (56) Recv failure: Connection reset by peer
```

Either proves plaintext was not accepted by the STRICT mTLS endpoint.

## AuthorizationPolicy Tests

Apply the unauthorized curl job:

```powershell
kubectl apply -f task-3-istio-zero-trust/manifests/30-unauthorized-curl.yaml
kubectl -n ledger wait --for=condition=complete job/unauthorized-curl --timeout=30s
kubectl -n ledger logs job/unauthorized-curl
kubectl -n ledger delete job unauthorized-curl
```

Expected unauthorized output:

```text
< HTTP/1.1 403 Forbidden
RBAC: access denied
```

The request reaches the mesh, has mTLS identity, but the identity is `cluster.local/ns/ledger/sa/unauthorized-curl`, which is not allowed.

Test the authorized neighbour:

```powershell
$NEIGHBOUR_POD = kubectl -n ledger get pod -l app.kubernetes.io/name=ledger-neighbour -o jsonpath="{.items[0].metadata.name}"
kubectl -n ledger exec $NEIGHBOUR_POD -c ledger-neighbour -- curl -sS -i http://ledger-api.ledger.svc.cluster.local:8080/health
```

If the neighbour container name is different, inspect it:

```powershell
kubectl -n ledger get pod $NEIGHBOUR_POD -o jsonpath="{range .spec.containers[*]}{.name}{'\n'}{end}"
```

Expected authorized output:

```text
HTTP/1.1 200 OK
...
{"status":"ok"}
```

## Bonus: Istio Ingress Gateway TLS

Create a local TLS secret:

```powershell
openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
  -keyout ledger.local.key `
  -out ledger.local.crt `
  -subj "/CN=ledger.local/O=ledger"
kubectl -n ledger create secret tls ledger-api-tls `
  --key ledger.local.key `
  --cert ledger.local.crt
kubectl apply -f task-3-istio-zero-trust/manifests/50-istio-ingress-gateway.yaml
```

Port-forward the gateway:

```powershell
kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443
curl -k -H "Host: ledger.local" https://localhost:8443/health
```

Expected output:

```text
{"status":"ok"}
```

## Bonus: Canary Traffic Split

The canary split manifest expects Task 1 or Task 2 deployment variants to label pods:

```text
version: stable
version: canary
```

Apply:

```powershell
kubectl apply -f task-3-istio-zero-trust/manifests/60-canary-traffic-split.yaml
```

Expected behavior:

```text
90% traffic -> ledger-api subset stable
10% traffic -> ledger-api subset canary
```

## Docs

```text
task-3-istio-zero-trust/docs/certs-and-trust.md
task-3-istio-zero-trust/docs/defense-in-depth.md
task-3-istio-zero-trust/docs/pci-cde-scope.md
```
