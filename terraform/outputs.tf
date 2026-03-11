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

output "kubeconfig_raw" {
  description = "Raw kubeconfig for this cluster. Sensitive output."
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  sensitive   = true
}
