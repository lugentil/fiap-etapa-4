resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  role_arn = var.lab_role_arn
  version  = "1.35"

  vpc_config {
    subnet_ids              = concat(var.subnet_ids, var.public_subnet_ids)
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  access_config {
    authentication_mode                        = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

resource "aws_eks_access_entry" "lab_role" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.lab_role_arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_access_policy_association" "lab_role_cluster_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.lab_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.lab_role]
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = var.lab_role_arn
  subnet_ids      = var.subnet_ids

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = "${var.project_name}-node-group"
  }

  depends_on = [aws_eks_cluster.main]
}
