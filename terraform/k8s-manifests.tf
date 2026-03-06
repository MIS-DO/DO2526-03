locals {
  k8s_manifest_files = fileset("${path.module}/../k8s/manifests", "**/*")

  k8s_manifests_hash = sha256(join("", [
    for f in local.k8s_manifest_files : file("${path.module}/../k8s/manifests/${f}")
  ]))
}

resource "null_resource" "k8s_manifests" {
  triggers = {
    manifests_hash       = local.k8s_manifests_hash
    preprod_namespace    = var.preprod_namespace
    prod_namespace       = var.prod_namespace
    search_api_image     = var.search_api_image
    songs_api_image      = var.songs_api_image
    movies_api_image     = var.movies_api_image
    football_api_image   = var.football_api_image
    mongo_image          = var.mongo_image
    api_replicas         = tostring(var.api_replicas)
    mongo_storage_size   = var.mongo_storage_size
    api_request_cpu      = var.api_request_cpu
    api_request_memory   = var.api_request_memory
    api_limit_cpu        = var.api_limit_cpu
    api_limit_memory     = var.api_limit_memory
    mongo_request_cpu    = var.mongo_request_cpu
    mongo_request_memory = var.mongo_request_memory
    mongo_limit_cpu      = var.mongo_limit_cpu
    mongo_limit_memory   = var.mongo_limit_memory
  }

  provisioner "local-exec" {
    command = "${path.module}/../k8s/deploy.sh"

    environment = {
      PREPROD_NAMESPACE    = var.preprod_namespace
      PROD_NAMESPACE       = var.prod_namespace
      SEARCH_API_IMAGE     = var.search_api_image
      SONGS_API_IMAGE      = var.songs_api_image
      MOVIES_API_IMAGE     = var.movies_api_image
      FOOTBALL_API_IMAGE   = var.football_api_image
      MONGO_IMAGE          = var.mongo_image
      API_REPLICAS         = tostring(var.api_replicas)
      MONGO_STORAGE_SIZE   = var.mongo_storage_size
      API_REQUEST_CPU      = var.api_request_cpu
      API_REQUEST_MEMORY   = var.api_request_memory
      API_LIMIT_CPU        = var.api_limit_cpu
      API_LIMIT_MEMORY     = var.api_limit_memory
      MONGO_REQUEST_CPU    = var.mongo_request_cpu
      MONGO_REQUEST_MEMORY = var.mongo_request_memory
      MONGO_LIMIT_CPU      = var.mongo_limit_cpu
      MONGO_LIMIT_MEMORY   = var.mongo_limit_memory
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/../k8s/destroy.sh"

    environment = {
      PREPROD_NAMESPACE    = self.triggers.preprod_namespace
      PROD_NAMESPACE       = self.triggers.prod_namespace
      SEARCH_API_IMAGE     = self.triggers.search_api_image
      SONGS_API_IMAGE      = self.triggers.songs_api_image
      MOVIES_API_IMAGE     = self.triggers.movies_api_image
      FOOTBALL_API_IMAGE   = self.triggers.football_api_image
      MONGO_IMAGE          = self.triggers.mongo_image
      API_REPLICAS         = self.triggers.api_replicas
      MONGO_STORAGE_SIZE   = self.triggers.mongo_storage_size
      API_REQUEST_CPU      = self.triggers.api_request_cpu
      API_REQUEST_MEMORY   = self.triggers.api_request_memory
      API_LIMIT_CPU        = self.triggers.api_limit_cpu
      API_LIMIT_MEMORY     = self.triggers.api_limit_memory
      MONGO_REQUEST_CPU    = self.triggers.mongo_request_cpu
      MONGO_REQUEST_MEMORY = self.triggers.mongo_request_memory
      MONGO_LIMIT_CPU      = self.triggers.mongo_limit_cpu
      MONGO_LIMIT_MEMORY   = self.triggers.mongo_limit_memory
    }
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}
