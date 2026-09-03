variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "This stack always runs against the management account"
  type        = string
  default     = "mgmt"
}

variable "project_prefix" {
  type    = string
  default = "capstone-9"
}

variable "workload_account_id" {
  description = "Account ID of the workload account (plays Production role for this capstone)"
  type        = string
  default     = "379549361194"
}