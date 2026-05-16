variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "node_type" {
  description = "Tipo de node do ElastiCache"
  type        = string
  default     = "cache.t3.micro"
}

variable "subnet_ids" {
  description = "IDs das subnets para o subnet group"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "allowed_sg_id" {
  description = "ID do security group com acesso ao Redis"
  type        = string
}
