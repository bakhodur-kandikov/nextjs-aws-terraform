# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]  # GitHub's OIDC thumbprint
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
            StringEquals = {
                "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
            },
            StringLike = {
                "token.actions.githubusercontent.com:sub": "repo:${var.github_repo}:*"
            }
        }
      }
    ]
  })
}

# IAM Policy for the Role
resource "aws_iam_role_policy" "github_actions_policy" {
  name   = "github-actions-policy"
  role   = aws_iam_role.github_actions_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchCheckLayerAvailability",
            "ecr:PutImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload",
            "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "sts:AssumeRoleWithWebIdentity",
        Resource = "*"
      }
    ]
  })
}

# Output
output "role_arn" {
  value = aws_iam_role.github_actions_role.arn
}