variable "aws_region" {
  description = "AWS region for the deployment. Default: eu-south-2."
  type        = string
  default     = "eu-south-2"
}

variable "dockerhub_user" {
  description = "Docker Hub namespace that publishes do2526-search-api and do2526-nginx-gateway as public images."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+([._-][a-z0-9]+)*$", var.dockerhub_user))
    error_message = "dockerhub_user must be a valid Docker Hub namespace."
  }
}

variable "image_tag" {
  description = "Docker image tag to deploy on EC2. Use an explicit version such as 1.0.0."
  type        = string

  validation {
    condition     = length(trimspace(var.image_tag)) > 0
    error_message = "image_tag must not be empty."
  }
}

variable "project_name" {
  description = "Project name used in tags and resource names."
  type        = string
  default     = "do2526-03"
}

variable "instance_type" {
  description = "EC2 instance type. t3.small is a safer default for 8 containers (nginx + 4 APIs + 3 MongoDB)."
  type        = string
  default     = "t3.small"
}

variable "use_eip" {
  description = "Whether to allocate and associate an Elastic IP to the instance."
  type        = bool
  default     = false
}

variable "ssm_role_name" {
  description = "IAM Role name used by EC2 for SSM Session Manager."
  type        = string
  default     = "do2526-ec2-ssm-role"

  validation {
    condition     = can(regex("^do2526-[a-z0-9-]+$", var.ssm_role_name))
    error_message = "ssm_role_name must start with 'do2526-' and contain only lowercase letters, numbers and dashes."
  }
}

variable "ssm_instance_profile_name" {
  description = "IAM Instance Profile name that attaches the SSM role to the EC2 instance."
  type        = string
  default     = "do2526-ec2-ssm-profile"

  validation {
    condition     = can(regex("^do2526-[a-z0-9-]+$", var.ssm_instance_profile_name))
    error_message = "ssm_instance_profile_name must start with 'do2526-' and contain only lowercase letters, numbers and dashes."
  }
}
