output "eks_cluster_endpoint" {
  description = "URL do endpoint do cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "rds_auth_endpoint" {
  description = "Endpoint do RDS do auth-service"
  value       = module.rds_auth.endpoint
}

output "rds_flags_endpoint" {
  description = "Endpoint do RDS do flag-service"
  value       = module.rds_flags.endpoint
}

output "rds_targeting_endpoint" {
  description = "Endpoint do RDS do targeting-service"
  value       = module.rds_targeting.endpoint
}

output "elasticache_endpoint" {
  description = "Endpoint do Redis"
  value       = module.elasticache.endpoint
}

output "sqs_queue_url" {
  description = "URL da fila SQS de eventos de avaliacao"
  value       = module.sqs.queue_url
}

output "dynamodb_table_name" {
  description = "Nome da tabela do DynamoDB"
  value       = module.dynamodb.table_name
}

output "ecr_repository_urls" {
  description = "URLs dos repositorios ECR"
  value       = module.ecr.repository_urls
}

output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.networking.vpc_id
}

output "argocd_namespace" {
  description = "Namespace onde o ArgoCD foi instalado"
  value       = kubernetes_namespace.argocd.metadata[0].name
}
