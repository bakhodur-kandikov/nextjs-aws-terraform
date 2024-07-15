variable "aws_region" {
  type = string #example: us-east-1
}
variable "github_repo" {
  type = string #example: bakhodur-kandikov/nextjs-aws-terraform
}
variable "ecr_image_tag" {
  type = string #example: latest
}
variable "ecr_repo_name" {
  type = string #example: nextapp
}