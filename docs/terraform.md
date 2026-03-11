# Terraform — DOKS + despliegue en DigitalOcean

Crea un cluster DOKS y despliega los mismos manifiestos de `k8s/` via `null_resource`.

> `null_resource` con `local-exec` para llamar a `k8s/deploy.sh` una vez el cluster está listo.
> Se re-ejecuta únicamente cuando cambia el hash de los manifiestos.

## Prerrequisitos

- `terraform`, `doctl`, `kubectl`
- Token de DigitalOcean

## Setup inicial

```bash
cd terraform
# Añadir token DO al .env:
echo 'TF_VAR_do_token="dop_v1_..."' >> .env
```

## Desplegar

```bash
./terraform/deploy.sh
```

Al finalizar imprime la IP del LoadBalancer. Es necesario añadirla al `.env`:

```bash
echo 'LB_ADDR=<ip>' >> terraform/.env
```

## Test funcional (prod via LoadBalancer)

```bash
./terraform/test-api.sh
```

Lee `LB_ADDR` del `.env` y valida los endpoints de prod.

## Demo HPA (escalado automático)

```bash
./terraform/test-hpa.sh
```

Mismo comportamiento que en local pero contra el cluster de DO.
Muestra el contexto activo al inicio para confirmar que apunta a DOKS.

## Destruir

```bash
./terraform/destroy.sh
```

## Cambiar entre clusters

```bash
kubectl config get-contexts
kubectl config use-context docker-desktop       # local
kubectl config use-context do-fra1-do2526-doks  # DigitalOcean
```
