resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-split-server-and-static-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
# Attach the necessary policies to the CodeBuild role
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:GetRepositoryPolicy",
            "ecr:DescribeRepositories",
            "ecr:ListImages",
            "ecr:DescribeImages",
            "ecr:BatchGetImage",
            "ecr:GetLifecyclePolicy",
            "ecr:GetLifecyclePolicyPreview",
            "ecr:ListTagsForResource",
            "ecr:DescribeImageScanFindings"
            
        ],
        # Resource = [
        #   "${aws_ecr_repository.nextapp.arn}",
        #   "${aws_ecr_repository.nextapp.arn}/*",
        # ]
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations",
          "cloudfront:ListDistributions"
        ],
        Resource = "*"
      },
    ]
  })
}

# Define the CodeBuild project
resource "aws_codebuild_project" "split_server_and_static_build" {
  name          = "split-server-and-static"
  build_timeout = 30

  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "${aws_ecr_repository.nextapp.repository_url}:${var.ecr_image_tag}"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"

    environment_variable {
      name  = "NEXT_STATIC_BUCKET"
      value = "${aws_s3_bucket.nextapp_static.bucket}"
    }
    environment_variable {
      name  = "CF_DISTRIBUTION"
      value = "${aws_cloudfront_distribution.nextapp_distribution.id}"
    }
  }

  source {
    type     = "CODEPIPELINE"
    buildspec = file("../codebuild/buildspec.yml")
  }

  cache {
    type = "LOCAL"
    modes = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = "codebuild-log-group"
      stream_name = "codebuild-log-stream"
    }
  }
}