module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  azs          = var.aws_availability_zones 
}

module "eks" {
  source             = "./modules/eks"
  project_name       = var.project_name
  subnet_ids         = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids
  vpc_id             = module.networking.vpc_id
  lab_role_arn       = data.aws_iam_role.lab_role.arn
  node_instance_type = var.eks_node_instance_type
  node_desired_size  = var.eks_node_desired
  node_min_size      = var.eks_node_min
  node_max_size      = var.eks_node_max
}

module "rds_auth" {
  source         = "./modules/rds"
  project_name   = var.project_name
  identifier     = "auth"
  db_name        = "auth_db"
  db_username    = "postgres"
  db_password    = var.db_passwords["auth_db"]
  instance_class = var.rds_instance_class
  subnet_ids     = module.networking.private_subnet_ids
  vpc_id         = module.networking.vpc_id
  allowed_sg_id  = module.eks.cluster_security_group_id
}

module "rds_flags" {
  source         = "./modules/rds"
  project_name   = var.project_name
  identifier     = "flags"
  db_name        = "flags_db"
  db_username    = "postgres"
  db_password    = var.db_passwords["flags_db"]
  instance_class = var.rds_instance_class
  subnet_ids     = module.networking.private_subnet_ids
  vpc_id         = module.networking.vpc_id
  allowed_sg_id  = module.eks.cluster_security_group_id
}

module "rds_targeting" {
  source         = "./modules/rds"
  project_name   = var.project_name
  identifier     = "targeting"
  db_name        = "targeting_db"
  db_username    = "postgres"
  db_password    = var.db_passwords["targeting_db"]
  instance_class = var.rds_instance_class
  subnet_ids     = module.networking.private_subnet_ids
  vpc_id         = module.networking.vpc_id
  allowed_sg_id  = module.eks.cluster_security_group_id
}

module "elasticache" {
  source        = "./modules/elasticache"
  project_name  = var.project_name
  node_type     = var.elasticache_node_type
  subnet_ids    = module.networking.private_subnet_ids
  vpc_id        = module.networking.vpc_id
  allowed_sg_id = module.eks.cluster_security_group_id
}

module "dynamodb" {
  source       = "./modules/dynamodb"
  project_name = var.project_name
  table_name   = "ToggleMasterAnalytics"
}

module "sqs" {
  source       = "./modules/sqs"
  project_name = var.project_name
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  repositories = var.ecr_repositories
}
