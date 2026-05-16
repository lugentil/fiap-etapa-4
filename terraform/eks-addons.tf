resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  preserve = true

  timeouts {
    create = "30m"
    update = "30m"
    delete = "20m"
  }

  depends_on = [module.eks]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  preserve = true

  timeouts {
    create = "30m"
    update = "30m"
    delete = "20m"
  }

  depends_on = [module.eks]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  preserve = true

  timeouts {
    create = "30m"
    update = "30m"
    delete = "20m"
  }

  depends_on = [
    module.eks,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
  ]
}
