output "state_bucket_name" {
  description = "S3 bucket holding remote Terraform state — use this in other stacks' backend blocks"
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table used for state locking — use this in other stacks' backend blocks"
  value       = aws_dynamodb_table.tf_locks.name
}

output "management_account_id" {
  description = "Account ID this bootstrap ran against (sanity check)"
  value       = data.aws_caller_identity.current.account_id
}