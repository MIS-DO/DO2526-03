project_name = "do2526"
do_region    = "fra1"
k8s_version  = "1.34.1-do.5"
node_size    = "s-2vcpu-4gb"
node_count   = 1

preprod_namespace = "search-preprod"
prod_namespace    = "search-prod"

search_api_image   = "jorgeflorentino8/searchapi:latest"
songs_api_image    = "danvelcam621/songs-api:latest"
movies_api_image   = "migencmar/moviesapi:latest"
football_api_image = "jorgeflorentino8/footballteamapi:latest"
mongo_image        = "mongo:7"

api_replicas         = 1
mongo_storage_size   = "1Gi"
api_request_cpu      = "20m"
api_request_memory   = "64Mi"
api_limit_cpu        = "150m"
api_limit_memory     = "192Mi"
mongo_request_cpu    = "30m"
mongo_request_memory = "96Mi"
mongo_limit_cpu      = "250m"
mongo_limit_memory   = "256Mi"

common_tags = ["education", "terraform", "kubernetes", "search-api"]
