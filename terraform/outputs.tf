output "cluster_name" {
  description = "DigitalOcean Kubernetes cluster name."
  value       = digitalocean_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "DigitalOcean Kubernetes cluster ID."
  value       = digitalocean_kubernetes_cluster.main.id
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = digitalocean_kubernetes_cluster.main.endpoint
}

output "preprod_namespace" {
  description = "Namespace used by preproduction."
  value       = var.preprod_namespace
}

output "prod_namespace" {
  description = "Namespace used by production."
  value       = var.prod_namespace
}

output "ingress_lb_ip" {
  description = "Ingress LoadBalancer public IP (empty if pending/unavailable)."
  value       = try(data.external.ingress_lb.result.ip, "")
}

output "ingress_lb_hostname" {
  description = "Ingress LoadBalancer hostname (empty if provider returns IP)."
  value       = try(data.external.ingress_lb.result.hostname, "")
}

output "ingress_lb_address" {
  description = "Ingress LoadBalancer address (IP preferred, hostname fallback)."
  value       = try(data.external.ingress_lb.result.ip != "" ? data.external.ingress_lb.result.ip : data.external.ingress_lb.result.hostname, "")
}

output "search_api_image" {
  description = "Image reference deployed for search-api."
  value       = local.search_api_image
}

output "kubeconfig_raw" {
  description = "Raw kubeconfig for this cluster. Sensitive output."
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  sensitive   = true
}
