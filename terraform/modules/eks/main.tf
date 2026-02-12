variable "project_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_desired_size" {
  type = number
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "tags" {
  type = map(string)
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = [var.public_subnet_id, var.private_subnet_id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  tags = merge(var.tags, { Name = var.cluster_name })
}

resource "aws_eks_node_group" "public" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-public-ng"
  node_role_arn   = var.node_role_arn
  subnet_ids      = [var.public_subnet_id]
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  tags = merge(var.tags, { Name = "${var.project_name}-public-ng" })
}

resource "aws_eks_node_group" "private" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-private-ng"
  node_role_arn   = var.node_role_arn
  subnet_ids      = [var.private_subnet_id]
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  tags = merge(var.tags, { Name = "${var.project_name}-private-ng" })
}

output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "public_node_group_arn" {
  value = aws_eks_node_group.public.arn
}

output "private_node_group_arn" {
  value = aws_eks_node_group.private.arn
}
