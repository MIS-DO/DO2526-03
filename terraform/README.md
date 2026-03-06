# Terraform: DOKS mononodo + despliegue de manifiestos compartidos

Terraform: infraestructura en DigitalOcean y reutiliza los manifiestos de `../k8s`.
Resultado:
- entorno `preprod` independiente
- entorno `prod` accesible por Ingress
- monitorizacion visual (Headlamp + metrics-server)

## Flujo

1. Archivos locales:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   cp .env.example .env
   ```
2. Token DO en  `.env`:
   ```bash
   TF_VAR_do_token="dop_v1_..."
   ```
3. Despliegue DOKS + workloads + ingress + dashboard:
   ```bash
   ./deploy.sh
   ```
5. Bajar todo:
   ```bash
   ./destroy.sh
   ```