data "aws_caller_identity" "workload" {}

data "aws_iam_policy_document" "devops_engineer_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.workload.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "devops_engineer" {
  name                 = "DevOpsEngineer"
  assume_role_policy   = data.aws_iam_policy_document.devops_engineer_trust.json
  permissions_boundary = aws_iam_policy.permission_boundary.arn

  tags = {
    Project = var.project_prefix
  }
}

# Deliberately broad identity policy — AdministratorAccess — attached so
# the boundary is doing the actual restricting. This is the proof point:
# even with full admin rights attached, the boundary's explicit denies
# still win, because permissions boundaries and identity policies are
# intersected, never unioned.
resource "aws_iam_role_policy_attachment" "devops_engineer_admin" {
  role       = aws_iam_role.devops_engineer.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}