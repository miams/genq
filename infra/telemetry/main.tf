terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Local backend for single-developer project.
  # Move to S3 backend if collaboration is needed later.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "genq-telemetry"
      ManagedBy = "terraform"
    }
  }
}
