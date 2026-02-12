variable "project_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

resource "aws_ecr_repository" "this" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, { Name = "${var.project_name}-ecr" })
}

output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}
