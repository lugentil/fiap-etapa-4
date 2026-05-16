resource "kubernetes_secret" "otel_newrelic_license" {
  metadata {
    name      = "otel-newrelic-license"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  data = {
    NEW_RELIC_LICENSE_KEY = var.newrelic_license_key
  }

  depends_on = [kubernetes_namespace.observability]
}

resource "kubernetes_secret" "grafana_alerting" {
  metadata {
    name      = "grafana-alerting-secrets"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  data = {
    DISCORD_WEBHOOK_URL   = var.discord_webhook_url
    PAGERDUTY_ROUTING_KEY = var.pagerduty_routing_key
    GITHUB_DISPATCH_TOKEN = var.github_dispatch_token
    GITHUB_REPO_FULL_NAME = var.github_repo_full_name
  }

  depends_on = [kubernetes_namespace.observability]
}
