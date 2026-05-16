variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "repositories" {
  description = "Lista de nomes dos repositorios ECR"
  type        = list(string)
}
