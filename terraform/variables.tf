variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "devops-assignment"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "devops-assignment-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "node_instance_types" {
  description = "Node group instance types"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  description = "Desired nodes per node group"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Min nodes per node group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Max nodes per node group"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    Project     = "devops-assignment"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}
