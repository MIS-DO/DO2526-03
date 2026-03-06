locals {
  cluster_name = "${var.project_name}-doks"
}

resource "digitalocean_kubernetes_cluster" "main" {
  name    = local.cluster_name
  region  = var.do_region
  version = var.k8s_version
  tags    = var.common_tags

  node_pool {
    name       = "default-pool"
    size       = var.node_size
    node_count = var.node_count
    tags       = var.common_tags
  }
}
