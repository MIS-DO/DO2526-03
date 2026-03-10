terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------
# Data sources (default VPC + subnets + AL2023 AMI)
# -------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 AMI via SSM parameter
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# AssumeRole policy for EC2
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# -------------------------
# Locals
# -------------------------
locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }

  subnet_id = sort(data.aws_subnets.default_vpc.ids)[0]

  instance_tags = merge(local.common_tags, {
    Name = "${var.project_name}-ec2"
  })

  effective_public_ip = var.use_eip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip
}

# -------------------------
# Security Group: ONLY port 80 inbound
# -------------------------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-http-only"
  description = "HTTP-only access for ${var.project_name}; no SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from the Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound (needed for yum/dnf, docker pulls, SSM endpoints, etc.)
  egress {
    description = "All outbound IPv4"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg"
  })
}

# -------------------------
# IAM for SSM Session Manager
# -------------------------
resource "aws_iam_role" "ec2_ssm" {
  # IMPORTANT: Name must match your SSO Permission Set inline policy restrictions
  name               = var.ssm_role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(local.common_tags, {
    Name = var.ssm_role_name
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  # IMPORTANT: Name must match your SSO Permission Set inline policy restrictions
  name = var.ssm_instance_profile_name
  role = aws_iam_role.ec2_ssm.name

  tags = merge(local.common_tags, {
    Name = var.ssm_instance_profile_name
  })
}

# -------------------------
# EC2 Instance
# -------------------------
resource "aws_instance" "app" {
  ami                         = nonsensitive(data.aws_ssm_parameter.al2023_ami.value)
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/user_data.sh", {
    dockerhub_user = var.dockerhub_user
    image_tag      = var.image_tag
    project_name   = var.project_name
  })

  # IMDSv2 required (good practice)
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = local.instance_tags

  depends_on = [aws_iam_role_policy_attachment.ssm_core]
}

# -------------------------
# Optional Elastic IP
# -------------------------
resource "aws_eip" "app" {
  count    = var.use_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.app.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-eip"
  })
}
