terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Intentionally LOCAL state here — this stack creates the remote backend
  # that every other stack (org, workload) will use. Bootstrapping a remote
  # backend with a config that itself needs a remote backend is circular,
  # so this one stack is the deliberate exception.
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}