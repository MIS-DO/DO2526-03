# Kubernetes manifests compartidos (Docker Desktop + DOKS)

Incluye:
- dos entornos independientes: `preprod` y `prod`
- `prod` accesible por Ingress
- monitorizacion visual con Headlamp + metrics-server

## Prerrequisitos

- `kubectl`
- `envsubst`
- `curl`
- contexto Kubernetes apuntando al cluster deseado

```bash
kubectl config current-context
```

## Deploy

```bash
./k8s/deploy.sh
```

## Test funcional de Search API

```bash
./k8s/test-api.sh
```

El test valida:
- `preprod` responde por `Service` (via port-forward)
- `prod` responde por `Ingress`
- `/api/v1/search` con y sin parametros
- `/docs` en producción

Si acabas de ejecutar `./k8s/destroy.sh`, primero debes volver a desplegar con `./k8s/deploy.sh`.

## Destroy

```bash
./k8s/destroy.sh
```

## Variables opcionales

- `PREPROD_NAMESPACE`, `PROD_NAMESPACE`
- `SEARCH_API_IMAGE`, `SONGS_API_IMAGE`, `MOVIES_API_IMAGE`, `FOOTBALL_API_IMAGE`, `MONGO_IMAGE`
- `API_REPLICAS`, `MONGO_STORAGE_SIZE`
- `API_REQUEST_CPU`, `API_REQUEST_MEMORY`, `API_LIMIT_CPU`, `API_LIMIT_MEMORY`
- `MONGO_REQUEST_CPU`, `MONGO_REQUEST_MEMORY`, `MONGO_LIMIT_CPU`, `MONGO_LIMIT_MEMORY`

## Test de producción por LoadBalancer

```bash
./terraform/test-prod-lb.sh
```

Ejemplo:

```bash
LB_ADDR="XXXXX" ./terraform/test-prod-lb.sh
```

