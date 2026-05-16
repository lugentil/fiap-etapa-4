variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "identifier" {
  description = "Identificador unico desta instancia RDS (ex: auth, flags, targeting)"
  type        = string
}

variable "db_name" {
  description = "Nome do database a ser criado"
  type        = string
}

variable "db_username" {
  description = "Usuario master do banco"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha do usuario master"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "Classe da instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "subnet_ids" {
  description = "IDs das subnets para o DB subnet group"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "allowed_sg_id" {
  description = "ID do security group com acesso liberado a esta instancia"
  type        = string
}
