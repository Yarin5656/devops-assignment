variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Existing AWS key pair name for SSH"
  type        = string
}

variable "create_alb" {
  description = "Create ALB in front of App EC2"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR for task VPC"
  type        = string
  default     = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs in different AZs"
  type        = list(string)
  default     = ["10.40.1.0/24", "10.40.2.0/24"]
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH into EC2 instances"
  type        = string
  default     = "0.0.0.0/0"
}

variable "jenkins_ui_cidr" {
  description = "CIDR allowed to access Jenkins UI (8080)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_ingress_cidr" {
  description = "CIDR allowed to access app endpoint/ALB"
  type        = string
  default     = "0.0.0.0/0"
}

variable "jenkins_admin_user" {
  description = "Bootstrap Jenkins local admin username"
  type        = string
  default     = "admin"
}

variable "jenkins_admin_password" {
  description = "Bootstrap Jenkins local admin password"
  type        = string
  sensitive   = true
}

variable "jenkins_plugins" {
  description = "Jenkins plugins to preinstall"
  type        = list(string)
  default = [
    "workflow-aggregator",
    "git",
    "docker-workflow",
    "credentials-binding",
    "ssh-agent",
    "pipeline-stage-view",
    "blueocean"
  ]
}
