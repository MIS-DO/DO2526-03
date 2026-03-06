data "external" "ingress_lb" {
  program = [
    "bash",
    "-lc",
    <<-EOT
      ip="$(kubectl -n default get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
      hostname="$(kubectl -n default get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
      printf '{"ip":"%s","hostname":"%s"}' "$ip" "$hostname"
    EOT
  ]

  depends_on = [null_resource.k8s_manifests]
}
