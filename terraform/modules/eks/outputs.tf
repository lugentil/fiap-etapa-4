output "cluster_endpoint" {
  description = "URL do endpoint do cluster EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_ca_certificate" {
  description = "Certificado CA do cluster (base64)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "ID do security group do cluster, usado nas regras de ingress dos bancos"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_group_id" {
  description = "ID do node group EKS. Exposto para que recursos de Helm/EKS Add-On possam depender dele explicitamente"
  value       = aws_eks_node_group.main.id
}

output "node_group_name" {
  description = "Nome do node group EKS"
  value       = aws_eks_node_group.main.node_group_name
}
