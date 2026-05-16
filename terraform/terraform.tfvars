aws_region             = "us-east-1"
project_name           = "togglemaster"
environment            = "production"
vpc_cidr               = "10.0.0.0/16"
eks_node_instance_type = "t3.medium"
eks_node_desired       = 2
eks_node_min           = 1
eks_node_max           = 3
rds_instance_class     = "db.t3.micro"
elasticache_node_type  = "cache.t3.micro"

db_passwords = {
  auth_db      = "Teste123Auth"
  flags_db     = "Teste123Flags"
  targeting_db = "Teste123Targeting"
}

master_key      = "togglemaster-master-key-faculdade"
service_api_key = "togglemaster-service-api-key-faculdade"
gitops_repo_url = "https://github.com/lugentil01/fiap-etapa-4.git"

aws_credentials = {
  access_key    = ""
  secret_key    = ""
  session_token = ""
}

newrelic_license_key   = ""
grafana_admin_password = ""
discord_webhook_url    = ""
pagerduty_routing_key  = ""
github_dispatch_token  = ""
github_repo_full_name  = "lugentil01/fiap-etapa-4"