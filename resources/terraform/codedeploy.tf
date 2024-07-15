

# IAM role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "codedeploy-assume-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codedeploy.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codedeploy_policy" {
  role = aws_iam_role.codedeploy_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "s3:Get*",
          "s3:List*",
          "cloudwatch:*",
          "autoscaling:*",
          "codedeploy:*",
          "iam:PassRole",
          "tag:GetResources",
        ],
        Resource = "*"
      }
    ]
  })
}

# Define the CodeDeploy application
resource "aws_codedeploy_app" "deploy_nextapp" {
  name = "deploy_nextapp"

  compute_platform = "Server"
}

# Define the CodeDeploy deployment group
resource "aws_codedeploy_deployment_group" "deploy_nextapp" {
  app_name              = aws_codedeploy_app.deploy_nextapp.name
  deployment_group_name = "nextapp-deployment-group"

  service_role_arn = aws_iam_role.codedeploy_role.arn

  deployment_config_name = "CodeDeployDefault.OneAtATime"

  auto_rollback_configuration {
    enabled = false
    events  = ["DEPLOYMENT_FAILURE"]
  }

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "nextjs-app"
    }
  }

  tags = {
    Name = "nextjs-app"
  }
}