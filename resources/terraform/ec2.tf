# Create a key pair

resource "aws_key_pair" "ssh_key" {
  key_name   = "ec2_ssh_key"
  public_key = file("~/.ssh/id_rsa.pub")  # Replace with your public key file path
}

resource "local_file" "docker_compose" {
  content = templatefile("../docker/docker-compose.yml", {
    IMAGE_NAME = "${aws_ecr_repository.nextapp.repository_url}:${var.ecr_image_tag}"
  })
  filename = "../generated/docker-compose.yml"
}

resource "aws_instance" "nextapp_server" {
  ami           = "ami-01b1be742d950fb7f"  # Replace with your desired AMI ID
  instance_type = "t3.micro"  # Replace with your desired instance type
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  depends_on = [ aws_vpc.main, aws_ecr_repository.nextapp, local_file.docker_compose ]

  key_name      = aws_key_pair.ssh_key.key_name

  subnet_id     = aws_subnet.ec2_subnet.id

  vpc_security_group_ids = [aws_security_group.nextapp_server_sg.id]

  provisioner "file" {
    source      = "../generated/docker-compose.yml"
    destination = "/home/ec2-user/docker-compose.yml"
    connection {
      type        = "ssh"
      user        = "ec2-user"  # Replace with the appropriate user for your AMI
      private_key = file("~/.ssh/id_rsa")  # Replace with your private key file path
      host        = self.public_ip
    }
  }
  provisioner "file" {
    source      = "../nginx/nginx.conf"
    destination = "/home/ec2-user/nginx.conf"

    connection {
      type        = "ssh"
      user        = "ec2-user"  # Replace with the appropriate user for your AMI
      private_key = file("~/.ssh/id_rsa")  # Replace with your private key file path
      host        = self.public_ip
    }
  }

  user_data = <<-EOF
              #!/bin/bash
              cd /home/ec2-user
              sudo yum update -y
              sudo yum install -y docker ruby wget
              sudo usermod -a -G docker ec2-user
              newgrp docker
              wget https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)
              sudo mv docker-compose-$(uname -s)-$(uname -m) /usr/local/bin/docker-compose
              sudo chmod -v +x /usr/local/bin/docker-compose
              sudo systemctl enable docker.service
              sudo systemctl start docker.service
              wget https://aws-codedeploy-${var.aws_region}.s3.${var.aws_region}.amazonaws.com/latest/install
              chmod +x ./install
              sudo ./install auto
              EOF

  tags = {
    Name = "nextjs-app"
  }
}

resource "aws_iam_role" "nextapp_server_ec2_role" {
  name = "NextAppServerEC2Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "nextapp-server-profile"
  role = aws_iam_role.nextapp_server_ec2_role.id
}


# Attach the necessary policies to the CodeBuild role
resource "aws_iam_role_policy" "codepipeline_codebuild_policy" {
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
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
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
            "CodeDeploy:GetAuthorizationToken",
        ],
        Resource = "*"
      },
    ]
  })
}

# Attach the necessary policies to the EC2 role
resource "aws_iam_role_policy" "nextapp_server_ec2_role_policy" {
  role = aws_iam_role.nextapp_server_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
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
    ]
  })
}