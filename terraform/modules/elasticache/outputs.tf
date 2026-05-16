output "endpoint" {
  description = "Endpoint do Redis (hostname)"
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
}

output "port" {
  description = "Porta do Redis"
  value       = aws_elasticache_cluster.main.port
}
