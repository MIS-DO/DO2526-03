locals {
  k8s_manifest_files = fileset("${path.module}/../k8s/manifests", "**/*")

  k8s_manifests_hash = sha256(join("", [
    for f in local.k8s_manifest_files : file("${path.module}/../k8s/manifests/${f}")
  ]))
}

resource "null_resource" "k8s_manifests" {
  triggers = {
    manifests_hash = local.k8s_manifests_hash
  }

  provisioner "local-exec" {
    command = "${path.module}/../k8s/deploy.sh"
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}
