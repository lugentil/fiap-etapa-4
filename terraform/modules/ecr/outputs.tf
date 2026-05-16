output "repository_urls" {
  description = "Mapa com as URLs dos repositorios ECR"
  value       = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}
