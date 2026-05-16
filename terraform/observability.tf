resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
    labels = {
      name = "observability"
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kps"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = "65.5.1"
  timeout    = 900

  values = [<<-YAML
    fullnameOverride: kps

    crds:
      enabled: true

    alertmanager:
      enabled: false

    prometheusOperator:
      resources:
        requests:
          cpu: 50m
          memory: 128Mi
        limits:
          memory: 256Mi

    prometheus:
      prometheusSpec:
        retention: 24h
        scrapeInterval: 30s
        evaluationInterval: 30s
        serviceMonitorSelectorNilUsesHelmValues: false
        ruleSelectorNilUsesHelmValues: false
        podMonitorSelectorNilUsesHelmValues: false
        probeSelectorNilUsesHelmValues: false
        resources:
          requests:
            cpu: 100m
            memory: 512Mi
          limits:
            memory: 1Gi

    grafana:
      enabled: true
      adminUser: admin
      adminPassword: ${var.grafana_admin_password}
      defaultDashboardsEnabled: true
      envFromSecret: grafana-alerting-secrets
      sidecar:
        dashboards:
          enabled: true
          searchNamespace: ALL
          label: grafana_dashboard
          labelValue: "1"
          provider:
            allowUiUpdates: true
        datasources:
          enabled: true
          searchNamespace: ALL
          label: grafana_datasource
          labelValue: "1"
          defaultDatasourceEnabled: false
        alerts:
          enabled: true
          searchNamespace: ALL
          label: grafana_alert
          labelValue: "1"
      additionalDataSources:
        - name: Prometheus
          uid: prometheus
          type: prometheus
          access: proxy
          url: http://kps-prometheus.observability.svc.cluster.local:9090
          isDefault: true
          jsonData:
            timeInterval: 30s
        - name: Loki
          uid: loki
          type: loki
          access: proxy
          url: http://loki.observability.svc.cluster.local:3100
          jsonData:
            maxLines: 1000
      grafana.ini:
        server:
          root_url: "%(protocol)s://%(domain)s/grafana"
          serve_from_sub_path: true
        auth.anonymous:
          enabled: false
      persistence:
        enabled: false
      resources:
        requests:
          cpu: 50m
          memory: 256Mi
        limits:
          memory: 512Mi
      service:
        type: ClusterIP
      ingress:
        enabled: true
        ingressClassName: nginx
        path: /grafana
        pathType: Prefix

    nodeExporter:
      enabled: true

    kubeStateMetrics:
      enabled: true

    kube-state-metrics:
      resources:
        requests:
          cpu: 20m
          memory: 64Mi
        limits:
          memory: 128Mi

    prometheus-node-exporter:
      resources:
        requests:
          cpu: 20m
          memory: 32Mi
        limits:
          memory: 64Mi

    kubeApiServer:
      enabled: true
    kubelet:
      enabled: true
    kubeControllerManager:
      enabled: false
    kubeScheduler:
      enabled: false
    kubeProxy:
      enabled: false
    kubeEtcd:
      enabled: false
  YAML
  ]

  depends_on = [
    kubernetes_namespace.observability,
    kubernetes_secret.grafana_alerting,
  ]
}

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = "6.16.0"
  timeout    = 600

  values = [<<-YAML
    deploymentMode: SingleBinary

    loki:
      auth_enabled: false
      commonConfig:
        replication_factor: 1
      storage:
        type: filesystem
      schemaConfig:
        configs:
          - from: 2024-01-01
            store: tsdb
            object_store: filesystem
            schema: v13
            index:
              prefix: index_
              period: 24h
      limits_config:
        retention_period: 24h
        ingestion_rate_mb: 10
        ingestion_burst_size_mb: 20
        allow_structured_metadata: true
        volume_enabled: true
      compactor:
        retention_enabled: true
        delete_request_store: filesystem

    singleBinary:
      replicas: 1
      persistence:
        enabled: false
      extraVolumes:
        - name: loki-data
          emptyDir: {}
      extraVolumeMounts:
        - name: loki-data
          mountPath: /var/loki
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          memory: 512Mi

    chunksCache:
      enabled: false
    resultsCache:
      enabled: false

    test:
      enabled: false

    lokiCanary:
      enabled: false

    monitoring:
      lokiCanary:
        enabled: false
      selfMonitoring:
        enabled: false
        grafanaAgent:
          installOperator: false

    minio:
      enabled: false

    backend:
      replicas: 0
    read:
      replicas: 0
    write:
      replicas: 0

    gateway:
      enabled: false
  YAML
  ]

  depends_on = [
    kubernetes_namespace.observability,
  ]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = "6.16.6"
  timeout    = 300

  values = [<<-YAML
    config:
      clients:
        - url: http://loki.observability.svc.cluster.local:3100/loki/api/v1/push
      snippets:
        pipelineStages:
          - cri: {}
          - labels:
              app:
              namespace:
              container:

    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        memory: 128Mi
  YAML
  ]

  depends_on = [helm_release.loki]
}

resource "helm_release" "opentelemetry_operator" {
  name       = "opentelemetry-operator"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-operator"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = "0.68.0"
  timeout    = 600

  values = [<<-YAML
    admissionWebhooks:
      certManager:
        enabled: false
      autoGenerateCert:
        enabled: true

    manager:
      collectorImage:
        repository: otel/opentelemetry-collector-contrib
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          memory: 128Mi
  YAML
  ]

  depends_on = [kubernetes_namespace.observability]
}
