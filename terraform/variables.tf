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
  default     = "1.35.1-do.0"
}

variable "node_size" {
  description = "Node size slug for DOKS pool."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "node_count" {
  description = "Number of nodes in the default node pool."
  type        = number
  default     = 1
}

variable "common_tags" {
  description = "Tags applied to DigitalOcean resources."
  type        = list(string)
  default     = ["education", "terraform", "kubernetes"]
}
