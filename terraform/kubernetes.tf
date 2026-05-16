resource "kubernetes_namespace" "services" {
  for_each = toset([
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service"
  ])

  metadata {
    name = each.key
  }
}

resource "kubernetes_secret" "auth_service" {
  metadata {
    name      = "auth-service-secrets"
    namespace = kubernetes_namespace.services["auth-service"].metadata[0].name
  }

  data = {
    DATABASE_URL = "postgres://postgres:${var.db_passwords["auth_db"]}@${module.rds_auth.endpoint}/auth_db"
    MASTER_KEY   = var.master_key
  }
}

resource "kubernetes_secret" "flag_service" {
  metadata {
    name      = "flag-service-secrets"
    namespace = kubernetes_namespace.services["flag-service"].metadata[0].name
  }

  data = {
    DATABASE_URL    = "postgres://postgres:${var.db_passwords["flags_db"]}@${module.rds_flags.endpoint}/flags_db"
    AUTH_SERVICE_URL = "http://auth-service.auth-service.svc:8001"
  }
}

resource "kubernetes_secret" "targeting_service" {
  metadata {
    name      = "targeting-service-secrets"
    namespace = kubernetes_namespace.services["targeting-service"].metadata[0].name
  }

  data = {
    DATABASE_URL    = "postgres://postgres:${var.db_passwords["targeting_db"]}@${module.rds_targeting.endpoint}/targeting_db"
    AUTH_SERVICE_URL = "http://auth-service.auth-service.svc:8001"
  }
}

resource "kubernetes_secret" "evaluation_service" {
  metadata {
    name      = "evaluation-service-secrets"
    namespace = kubernetes_namespace.services["evaluation-service"].metadata[0].name
  }

  data = {
    REDIS_URL             = "redis://${module.elasticache.endpoint}:6379"
    PORT                  = "8004"
    FLAG_SERVICE_URL      = "http://flag-service.flag-service.svc:8002"
    TARGETING_SERVICE_URL = "http://targeting-service.targeting-service.svc:8003"
    SERVICE_API_KEY       = var.service_api_key
    AWS_SQS_URL           = module.sqs.queue_url
  }
}

resource "kubernetes_secret" "analytics_service" {
  metadata {
    name      = "analytics-service-secrets"
    namespace = kubernetes_namespace.services["analytics-service"].metadata[0].name
  }

  data = {
    PORT               = "8005"
    AWS_SQS_URL        = module.sqs.queue_url
    AWS_DYNAMODB_TABLE = module.dynamodb.table_name
  }
}

resource "kubernetes_secret" "aws_credentials_evaluation" {
  metadata {
    name      = "aws-credentials"
    namespace = kubernetes_namespace.services["evaluation-service"].metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.aws_credentials.access_key
    AWS_SECRET_ACCESS_KEY = var.aws_credentials.secret_key
    AWS_SESSION_TOKEN     = var.aws_credentials.session_token
    AWS_REGION            = var.aws_region
  }
}

resource "kubernetes_secret" "aws_credentials_analytics" {
  metadata {
    name      = "aws-credentials"
    namespace = kubernetes_namespace.services["analytics-service"].metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.aws_credentials.access_key
    AWS_SECRET_ACCESS_KEY = var.aws_credentials.secret_key
    AWS_SESSION_TOKEN     = var.aws_credentials.session_token
    AWS_REGION            = var.aws_region
  }
}
