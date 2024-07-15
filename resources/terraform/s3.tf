resource "aws_s3_bucket" "code_deploy_app_spec" {
  bucket = "code-deploy-app-spec"  # Replace with your desired bucket name
}

resource "aws_s3_bucket" "nextapp_static" {
  bucket = "nextapp-static-files"  # Replace with your desired bucket name
}

resource "aws_s3_bucket_ownership_controls" "code_deploy_app_spec" {
  bucket = aws_s3_bucket.code_deploy_app_spec.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_ownership_controls" "nextapp_static" {
  bucket = aws_s3_bucket.nextapp_static.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "code_deploy_app_spec" {

  depends_on = [aws_s3_bucket_ownership_controls.code_deploy_app_spec]

  bucket = aws_s3_bucket.code_deploy_app_spec.id
  acl    = "private"
}
resource "aws_s3_bucket_acl" "nextapp_static" {

  depends_on = [aws_s3_bucket_ownership_controls.nextapp_static]

  bucket = aws_s3_bucket.nextapp_static.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "code_deploy_app_spec" {
  bucket = aws_s3_bucket.code_deploy_app_spec.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "app_spec" {
  depends_on = [ data.archive_file.appspec_codedeploy ]
  bucket = aws_s3_bucket.code_deploy_app_spec.id
  key    = "AppSpec.zip" 
  source = "../generated/AppSpec.zip" 
  acl    = "private"
}

data "archive_file" "appspec_codedeploy" {
  type        = "zip"
  output_path = "../generated/AppSpec.zip"
  excludes = ["../codedeploy/scripts/before_install.sh", "../codedeploy/scripts/ecr-login.sh"]

  source {
    content  = templatefile("../codedeploy/scripts/before_install.sh", {
      IMAGE_NAME = "${aws_ecr_repository.nextapp.repository_url}:${var.ecr_image_tag}"
    })
    filename = "scripts/before_install.sh"
  }

  source {
    content  = templatefile("../codedeploy/scripts/ecr-login.sh", {
      ECR_REPO = "${aws_ecr_repository.nextapp.registry_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
      AWS_REGION = "${var.aws_region}"
    })
    filename = "scripts/ecr-login.sh"
  }
  source {
    content  = file("../codedeploy/scripts/app_start.sh")
    filename = "scripts/app_start.sh"
  }
  source {
    content  = file("../codedeploy/scripts/app_stop.sh")
    filename = "scripts/app_stop.sh"
  }
  source {
    content  = file("../codedeploy/appspec.yml")
    filename = "appspec.yml"
  }
}