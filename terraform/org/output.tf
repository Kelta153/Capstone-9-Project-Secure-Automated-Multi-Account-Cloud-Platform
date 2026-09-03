output "root_id" {
  value = local.root_id
}

output "security_ou_id" {
  value = aws_organizations_organizational_unit.security.id
}

output "production_ou_id" {
  value = aws_organizations_organizational_unit.production.id
}

output "development_ou_id" {
  value = aws_organizations_organizational_unit.development.id
}

output "scp_id" {
  value = aws_organizations_policy.deny_destructive_actions.id
}

output "trail_bucket_name" {
  value = aws_s3_bucket.trail_logs.bucket
}

output "org_id" {
  value = data.aws_organizations_organization.this.id
}