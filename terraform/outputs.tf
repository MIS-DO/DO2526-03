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

output "ingress_lb_ip" {
  description = "Ingress LoadBalancer public IP (empty if pending/unavailable)."
  value       = try(data.external.ingress_lb.result.ip, "")
}

output "ingress_lb_hostname" {
  description = "Ingress LoadBalancer hostname (empty if provider returns IP)."
  value       = try(data.external.ingress_lb.result.hostname, "")
}

output "kubeconfig_raw" {
  description = "Raw kubeconfig for this cluster. Sensitive output."
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  sensitive   = true
}
