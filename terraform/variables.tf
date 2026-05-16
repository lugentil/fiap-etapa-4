variable "aws_region" {
  description = "Regiao da AWS"
  default     = "us-east-1"
}

variable "aws_availability_zones" {
  description = "Lista de AZs"
  type        = list(string)
  default     = [ "us-east-1a", "us-east-1b" ]
}

variable "project_name" {
  description = "Nome do projeto para os recursos"
  default     = "togglemaster"
}

variable "environment" {
  description = "Ambiente"
  default     = "production"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  default     = "10.0.0.0/16"
}

variable "eks_node_instance_type" {
  description = "Instancia EC2 para NP"
  default     = "t3.medium"
}

variable "eks_node_desired" {
  description = "Quantidade nodes para o NP"
  default     = 2
}

variable "eks_node_min" {
  description = "Quantidade minima de nodes para o NP"
  default     = 1
}

variable "eks_node_max" {
  description = "Quantidade maxima de nodes para o NP"
  default     = 3
}

variable "rds_instance_class" {
  description = "Shape para os bancos PostgreSQL"
  default     = "db.t3.micro"
}

variable "elasticache_node_type" {
  description = "Tipo de node do ElastiCache Redis"
  default     = "cache.t3.micro"
}

variable "db_passwords" {
  description = "Senhas dos bancos de dados"
  type        = map(string)
  sensitive   = true
  default     = null

  validation {
    condition = try(alltrue([
      for key in ["auth_db", "flags_db", "targeting_db"] :
      contains(keys(var.db_passwords), key) && try(length(trimspace(var.db_passwords[key])) >= 8, false)
    ]), false)
    error_message = "Preencha db_passwords em terraform.tfvars com as chaves auth_db, flags_db e targeting_db. Cada senha precisa ter pelo menos 8 caracteres. Nao digite var.db_passwords no prompt do Terraform."
  }
}

variable "ecr_repositories" {
  description = "Lista de repositorios ECR"
  default = [
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service"
  ]
}

variable "master_key" {
  description = "Chave do auth-service para criacao de API keys"
  type        = string
  sensitive   = true
  default     = "togglemaster-secret-key"
}

variable "service_api_key" {
  description = "Service API para o evaluation-service"
  type        = string
  sensitive   = true
  default     = "togglemaster-api-key"
}

variable "gitops_repo_url" {
  description = "URL do repositorio Git que o ArgoCD monitora para sincronizar os deploys"
  type        = string
  default     = "https://github.com/tc-fiap-lacf/fiap-etapa-4.git"
}

variable "aws_credentials" {
  description = "Credenciais AWS para recursos Kubernetes"
  type = object({
    access_key    = string
    secret_key    = string
    session_token = string
  })
  sensitive = true
  default = {
    access_key    = ""
    secret_key    = ""
    session_token = ""
  }
}

variable "newrelic_license_key" {
  description = "Ingest License Key do New Relic para envio de telemetria via OTLP"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_admin_password" {
  description = "Senha do usuario admin do Grafana"
  type        = string
  sensitive   = true
  default     = "togglemaster-admin"
}

variable "discord_webhook_url" {
  description = "URL do webhook Discord para notificacoes de alerta (ChatOps)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "pagerduty_routing_key" {
  description = "Integration Key do PagerDuty Events API v2"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_dispatch_token" {
  description = "GitHub PAT usado pelo webhook Grafana para acionar repository_dispatch (self-healing)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_repo_full_name" {
  description = "Repositorio GitHub no formato owner/repo usado no webhook de self-healing"
  type        = string
  default     = "tc-fiap-lacf/fiap-etapa-4"
}
