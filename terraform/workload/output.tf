output "permission_boundary_arn" {
  value = aws_iam_policy.permission_boundary.arn
}

output "devops_engineer_role_arn" {
  value = aws_iam_role.devops_engineer.arn
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_actions_deploy_role_arn" {
  value = aws_iam_role.github_actions_deploy.arn
}

output "workload_account_id" {
  value = data.aws_caller_identity.workload.account_id
}