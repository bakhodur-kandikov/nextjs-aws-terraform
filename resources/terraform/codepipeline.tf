resource "aws_codepipeline" "codepipeline" {
  name     = "nextapp-deploy-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "AppSources"

    action {
      name             = "NextAppImage"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_ecr_repository.nextapp.name
        ImageTag       = var.ecr_image_tag
      }
    }

    action {
      name             = "CodeDeployAppSpec"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["app_spec_output"]

      configuration = {
        S3Bucket    = aws_s3_bucket.code_deploy_app_spec.bucket
        S3ObjectKey = "AppSpec.zip"
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "SplitStaticAndServerBuild"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.split_server_and_static_build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["app_spec_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.deploy_nextapp.name
        DeploymentGroupName = aws_codedeploy_deployment_group.deploy_nextapp.deployment_group_name
      }
    }
  }
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "codepipeline-source-nextapp"
}

resource "aws_s3_bucket_public_access_block" "codepipeline_bucket_pab" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
# Define the IAM role for CodePipeline
resource "aws_iam_role" "codepipeline_codedeploy_role" {
  name = "codepipeline-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "codepipeline-source-access-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning"
    ]
    resources = [
      aws_s3_bucket.code_deploy_app_spec.arn,
      "${aws_s3_bucket.code_deploy_app_spec.arn}/*"
    ]
  }
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.codepipeline_bucket.arn,
      "${aws_s3_bucket.codepipeline_bucket.arn}/*",
    ]
  }
  
  statement {
    effect = "Allow"

    actions = [
      "ecr:DescribeImages",
    ]

    resources = [
      aws_ecr_repository.nextapp.arn,
      "${aws_ecr_repository.nextapp.arn}/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "codepipeline_policy"
  role   = aws_iam_role.codepipeline_role.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

resource "aws_cloudwatch_event_rule" "ecr_image_push" {
  name     = "nextapp-ecr-image-push"
  role_arn = aws_iam_role.cwe_role.arn

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Action"]

    detail = {
      repository-name = [aws_ecr_repository.nextapp.name]
      image-tag       = [var.ecr_image_tag]
      action-type     = ["PUSH"]
      result          = ["SUCCESS"]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecr_image_push" {
  rule      = aws_cloudwatch_event_rule.ecr_image_push.name
  target_id = "${aws_ecr_repository.nextapp.name}-Codepipeline-Push"
  arn       = aws_codepipeline.codepipeline.arn
  role_arn  = aws_iam_role.cwe_role.arn
}

resource "aws_iam_role" "cwe_role" {
  name               = "nextapp-cwe-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": ["events.amazonaws.com"]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

# Allow EventBridge to Invoke CodePipeline
resource "aws_iam_policy" "allow_eventbridge" {
  name   = "allow_eventbridge_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "codepipeline:StartPipelineExecution",
        Resource = aws_codepipeline.codepipeline.arn
      }
    ]
  })
}
resource "aws_iam_policy_attachment" "cws_policy_attachment" {
  name       = "nextapp-cwe-policy"
  roles      = [aws_iam_role.cwe_role.name]
  policy_arn = aws_iam_policy.allow_eventbridge.arn
}