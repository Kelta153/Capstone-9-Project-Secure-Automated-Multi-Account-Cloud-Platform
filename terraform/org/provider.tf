terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "capstone-9-tfstate-004078028366"
    key            = "org/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "capstone-9-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}