variable "project_name" {
  description = "Nome do projeto para tagear os recursos"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
}

variable "azs" {
  description = "Zonas de disponibilidade a serem utilizadas"
  type        = list(string)
}
