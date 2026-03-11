# Kubernetes (local — Docker Desktop)

Despliega los dos entornos en el cluster local usando los manifiestos de `k8s/manifests/`.

## Prerrequisitos

- `kubectl` apuntando al cluster deseado
- `curl`

```bash
kubectl config current-context   # debe ser docker-desktop
```

## Desplegar

```bash
./k8s/deploy.sh
```

Aplica plataforma (ingress-nginx, metrics-server, headlamp) y workloads (preprod + prod).
Al finalizar imprime el token de Headlamp y la URL del dashboard.

## Test funcional

```bash
./k8s/test-api.sh
```

Valida:
- `search-preprod`: responde via port-forward al Service
- `search-prod`: responde via port-forward al Ingress controller
- `/api/v1/search` con y sin parámetros
- `/docs/`

## Demo HPA (escalado automático)

```bash
./k8s/test-hpa.sh
```

Lanza un pod de carga en `search-prod`, observa cómo el HPA escala las APIs por encima del umbral de CPU (20%) y limpia al terminar.

## Destruir

```bash
./k8s/destroy.sh
```

## Cambiar de cluster

```bash
kubectl config get-contexts
kubectl config use-context <nombre>
```
