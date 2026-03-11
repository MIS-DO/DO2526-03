#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="search-prod"
POD_NAME="load-test"
HPA_NAME="search-api-hpa"

cleanup() {
  kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" --ignore-not-found
  kubectl scale deployment songs-api movies-api football-api search-api \
    -n "${NAMESPACE}" --replicas=1
  kubectl get pods -n "${NAMESPACE}" | grep -v mongo
}
trap cleanup EXIT

echo "Lanzando carga..."
kubectl run "${POD_NAME}" -n "${NAMESPACE}" \
  --image=busybox \
  --restart=Never \
  -- /bin/sh -c "while true; do wget -q -O- http://search-api/api/v1/search?year=2010; done"

echo "Esperando escalado... (umbral CPU: 20%)"

for _ in $(seq 1 30); do
  sleep 10
  REPLICAS=$(kubectl get hpa "${HPA_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo "1")
  kubectl get hpa -n "${NAMESPACE}"
  echo "---"
  if [ "${REPLICAS}" -gt 1 ]; then
    break
  fi
done

echo "Escalado finalizado."
kubectl get pods -n "${NAMESPACE}" | grep -v mongo
