resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # thumbprint_list intentionally omitted — the AWS provider fetches it
  # automatically via TLS for supported IdPs, avoiding the brittleness of
  # a hardcoded thumbprint (GitHub rotated theirs in 2023 and broke every
  # OIDC setup that had one pinned).
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restricts to a specific repo AND branch. GitHub's subject claim now
    # embeds immutable numeric owner/repo IDs alongside the names
    # (repo:owner@ownerId/repo@repoId:ref:...) specifically to prevent
    # spoofing via repo renames or ownership transfers — confirmed by
    # decoding the actual token GitHub issues, since the plain
    # name-only format (used in most older tutorials) never matches.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${split("/", var.github_repo)[0]}@${var.github_owner_id}/${split("/", var.github_repo)[1]}@${var.github_repo_id}:ref:refs/heads/${var.github_branch}"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name                 = "${var.project_prefix}-github-actions-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_trust.json
  permissions_boundary = aws_iam_policy.permission_boundary.arn

  tags = {
    Project = var.project_prefix
  }
}

# Scoped down for CI/CD — deploy-shaped permissions rather than full
# admin. Widen as later pillars need specific new permissions.
data "aws_iam_policy_document" "github_actions_deploy_permissions" {
  statement {
    sid    = "AllowCoreDeployActions"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
      "cloudformation:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy_permissions" {
  name   = "${var.project_prefix}-deploy-permissions"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy_permissions.json
}