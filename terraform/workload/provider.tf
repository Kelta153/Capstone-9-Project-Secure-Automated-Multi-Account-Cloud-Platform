terraform {
  required_version = ">= 1.9.0"

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

  backend "s3" {
    bucket         = "capstone-9-tfstate-004078028366"
    key            = "workload/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "capstone-9-tf-locks"
    encrypt        = true
    profile        = "mgmt" # state bucket lives in the management account
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile # resources are created in the workload account
}