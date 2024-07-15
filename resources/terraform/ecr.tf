resource "aws_ecr_repository" "nextapp" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false 
  }
}

resource "aws_ecr_lifecycle_policy" "nextapp_lifecycle" {
  repository = aws_ecr_repository.nextapp.name
    policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 2 days",
            "selection": {
              "tagStatus": "any",
              "countType": "imageCountMoreThan",
              "countNumber": 2
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

# Output the repository URL
output "repository_url" {
  value = aws_ecr_repository.nextapp.repository_url
}