resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.2"
  timeout    = 900

  atomic          = false
  cleanup_on_fail = false
  wait            = true
  wait_for_jobs   = false
  force_update    = true
  recreate_pods   = false

  values = [<<-YAML
    defaultArgs:
      - --cert-dir=/tmp
      - --secure-port=10250
      - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
      - --kubelet-use-node-status-port
      - --metric-resolution=15s
      - --kubelet-insecure-tls
    apiService:
      insecureSkipTLSVerify: true
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        memory: 128Mi
    tolerations:
      - operator: Exists
  YAML
  ]

  depends_on = [module.eks]
}
