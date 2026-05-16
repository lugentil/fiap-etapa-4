variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets privadas para os nodes do EKS"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "IDs das subnets publicas para o endpoint do cluster"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "lab_role_arn" {
  description = "ARN da LabRole"
  type        = string
}

variable "node_instance_type" {
  description = "Tipo de instancia EC2 dos worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Quantidade desejada de worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Quantidade minima de worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Quantidade maxima de worker nodes"
  type        = number
  default     = 4
}
