variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "table_name" {
  description = "Nome da tabela DynamoDB"
  type        = string
  default     = "ToggleMasterAnalytics"
}
