output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Auto-assigned public IPv4 of the EC2 instance."
  value       = aws_instance.app.public_ip
}

output "elastic_ip" {
  description = "Elastic IP, if enabled; null otherwise."
  value       = try(aws_eip.app[0].public_ip, null)
}

output "service_ip" {
  description = "IP to use for HTTP checks and browser access (EIP if enabled, else instance public IP)."
  value       = local.effective_public_ip
}

output "session_manager_hint" {
  description = "How to connect to the instance with Systems Manager Session Manager."
  value       = <<-EOT
  AWS Console:
  1. Open Systems Manager in region ${var.aws_region}.
  2. Go to Fleet Manager or Session Manager.
  3. Start a session against instance ${aws_instance.app.id}.

  AWS CLI:
  aws ssm start-session --region ${var.aws_region} --target ${aws_instance.app.id}
  EOT
}

output "urls" {
  description = "Gateway URLs exposed by the EC2 instance."
  value = {
    healthz       = "http://${local.effective_public_ip}/healthz"
    search_docs   = "http://${local.effective_public_ip}/search/docs"
    songs_docs    = "http://${local.effective_public_ip}/songs/docs"
    movies_docs   = "http://${local.effective_public_ip}/movies/docs"
    football_docs = "http://${local.effective_public_ip}/football/docs"
    search_api    = "http://${local.effective_public_ip}/search/api/v1/search?year=2010"
  }
}
