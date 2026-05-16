output "endpoint" {
  description = "Endpoint da instancia RDS (host:porta)"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "Hostname da instancia RDS"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "Porta da instancia RDS"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Nome do database"
  value       = aws_db_instance.main.db_name
}
