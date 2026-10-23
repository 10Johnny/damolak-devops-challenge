variable "project_name" {
  description = "Name of the project"
  type        = string
}

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = "${var.project_name}-api"
    Project = var.project_name
  }
}

output "repository_url" {
  description = "URL used to push and pull the application image"
  value       = aws_ecr_repository.app.repository_url
}