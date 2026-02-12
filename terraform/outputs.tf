output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "eks_cluster_iam_role_arn" {
  description = "IAM role ARN used by EKS control plane"
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_iam_role_arn" {
  description = "IAM role ARN used by EKS node groups"
  value       = module.iam.eks_node_role_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = module.vpc.public_subnet_id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = module.vpc.private_subnet_id
}

output "public_node_group_arn" {
  description = "Public node group ARN"
  value       = module.eks.public_node_group_arn
}

output "private_node_group_arn" {
  description = "Private node group ARN"
  value       = module.eks.private_node_group_arn
}
