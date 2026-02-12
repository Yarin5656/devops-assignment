data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  common_tags = merge(var.tags, {
    Name = var.project_name
  })
}

module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zones  = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  tags                = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  tags         = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  public_subnet_id    = module.vpc.public_subnet_id
  private_subnet_id   = module.vpc.private_subnet_id
  cluster_role_arn    = module.iam.eks_cluster_role_arn
  node_role_arn       = module.iam.eks_node_role_arn
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  tags                = local.common_tags

  depends_on = [module.iam, module.vpc]
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  tags         = local.common_tags
}
