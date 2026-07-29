#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.local/bin:${HOME}/go/bin:/usr/local/bin:${PATH}"

NAMESPACE="${NAMESPACE:-ledger}"
SECRET_NAME="${SECRET_NAME:-ledger-api-secrets}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
  --from-literal=STRIPE_API_KEY="${STRIPE_API_KEY:-replace-me-in-runtime}" \
  --from-literal=DB_PASSWORD="${DB_PASSWORD:-replace-me-in-runtime}" \
  --dry-run=client -o yaml |
  kubeseal \
    --controller-name sealed-secrets \
    --controller-namespace kube-system \
    --format yaml > "task-1-workload-hardening/secrets/ledger-api-sealedsecret.yaml"

echo "Wrote task-1-workload-hardening/secrets/ledger-api-sealedsecret.yaml"
