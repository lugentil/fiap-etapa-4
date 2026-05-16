resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [module.eks]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "5.51.6"

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  set {
    name  = "configs.params.server\\.rootpath"
    value = "/argocd"
  }

  depends_on = [kubernetes_namespace.argocd]
}

resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-ingress"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/backend-protocol"  = "HTTP"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
    }
  }

  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path      = "/argocd"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd, helm_release.ingress_nginx]
}

resource "kubectl_manifest" "argocd_project" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: AppProject
    metadata:
      name: togglemaster
      namespace: argocd
    spec:
      description: ToggleMaster Feature Flag Platform
      sourceRepos:
        - '*'
      destinations:
        - namespace: auth-service
          server: https://kubernetes.default.svc
        - namespace: flag-service
          server: https://kubernetes.default.svc
        - namespace: targeting-service
          server: https://kubernetes.default.svc
        - namespace: evaluation-service
          server: https://kubernetes.default.svc
        - namespace: analytics-service
          server: https://kubernetes.default.svc
        - namespace: argocd
          server: https://kubernetes.default.svc
        - namespace: observability
          server: https://kubernetes.default.svc
      clusterResourceWhitelist:
        - group: ''
          kind: Namespace
        - group: networking.k8s.io
          kind: IngressClass
  YAML

  depends_on = [helm_release.argocd]
}

locals {
  argocd_services = [
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service"
  ]
}

resource "kubectl_manifest" "argocd_application" {
  for_each = toset(local.argocd_services)

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: ${each.key}
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: togglemaster
      source:
        repoURL: ${var.gitops_repo_url}
        targetRevision: main
        path: gitops/apps/${each.key}
      destination:
        server: https://kubernetes.default.svc
        namespace: ${each.key}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
        retry:
          limit: 3
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
      ignoreDifferences:
        - group: ''
          kind: Secret
          jsonPointers:
            - /data
  YAML

  depends_on = [kubectl_manifest.argocd_project]
}

resource "kubectl_manifest" "argocd_application_observability" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: observability
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: togglemaster
      source:
        repoURL: ${var.gitops_repo_url}
        targetRevision: main
        path: gitops/observability
        directory:
          recurse: true
      destination:
        server: https://kubernetes.default.svc
        namespace: observability
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
        retry:
          limit: 5
          backoff:
            duration: 10s
            factor: 2
            maxDuration: 5m
      ignoreDifferences:
        - group: ''
          kind: Secret
          jsonPointers:
            - /data
  YAML

  depends_on = [
    kubectl_manifest.argocd_project,
    helm_release.opentelemetry_operator,
    helm_release.kube_prometheus_stack,
    helm_release.loki,
  ]
}
