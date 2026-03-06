variable "do_token" {
  description = "DigitalOcean API token (use TF_VAR_do_token env var, do not hardcode)."
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Prefix used to name resources."
  type        = string
  default     = "do2526"
}

variable "do_region" {
  description = "DigitalOcean region for the cluster."
  type        = string
  default     = "fra1"
}

variable "k8s_version" {
  description = "DOKS version slug. Example: 1.34.1-do.5"
  type        = string
  default     = "1.34.1-do.5"
}

variable "node_size" {
  description = "Node size slug for DOKS pool."
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "node_count" {
  description = "Number of nodes in the default node pool."
  type        = number
  default     = 1
}

variable "preprod_namespace" {
  description = "Namespace for the preproduction environment."
  type        = string
  default     = "search-preprod"
}

variable "prod_namespace" {
  description = "Namespace for the production environment."
  type        = string
  default     = "search-prod"
}

variable "search_api_image" {
  description = "Full Docker image for search-api. Example: jorgeflorentino8/searchapi:latest"
  type        = string
  default     = "jorgeflorentino8/searchapi:latest"
}

variable "songs_api_image" {
  description = "Container image for songs-api."
  type        = string
  default     = "danvelcam621/songs-api:latest"
}

variable "movies_api_image" {
  description = "Container image for movies-api."
  type        = string
  default     = "migencmar/moviesapi:latest"
}

variable "football_api_image" {
  description = "Container image for football-api."
  type        = string
  default     = "jorgeflorentino8/footballteamapi:latest"
}

variable "mongo_image" {
  description = "Container image for MongoDB."
  type        = string
  default     = "mongo:7"
}

variable "api_replicas" {
  description = "Replica count for each API deployment."
  type        = number
  default     = 1
}

variable "mongo_storage_size" {
  description = "Persistent volume size for each MongoDB instance."
  type        = string
  default     = "1Gi"
}

variable "api_request_cpu" {
  description = "CPU request for each API container."
  type        = string
  default     = "20m"
}

variable "api_request_memory" {
  description = "Memory request for each API container."
  type        = string
  default     = "64Mi"
}

variable "api_limit_cpu" {
  description = "CPU limit for each API container."
  type        = string
  default     = "150m"
}

variable "api_limit_memory" {
  description = "Memory limit for each API container."
  type        = string
  default     = "192Mi"
}

variable "mongo_request_cpu" {
  description = "CPU request for each MongoDB container."
  type        = string
  default     = "30m"
}

variable "mongo_request_memory" {
  description = "Memory request for each MongoDB container."
  type        = string
  default     = "96Mi"
}

variable "mongo_limit_cpu" {
  description = "CPU limit for each MongoDB container."
  type        = string
  default     = "250m"
}

variable "mongo_limit_memory" {
  description = "Memory limit for each MongoDB container."
  type        = string
  default     = "256Mi"
}

variable "common_tags" {
  description = "Tags applied to DigitalOcean resources."
  type        = list(string)
  default     = ["education", "terraform", "kubernetes"]
}
