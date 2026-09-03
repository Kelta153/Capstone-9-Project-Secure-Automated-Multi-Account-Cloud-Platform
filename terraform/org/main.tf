data "aws_organizations_organization" "this" {}

locals {
  root_id = data.aws_organizations_organization.this.roots[0].id
}

# --- Organizational Units -----------------------------------------------
# Sibling OUs under root, mirroring real Control Tower / Landing Zone
# layout (Security and workload OUs are peers, not nested inside each
# other). Security OU is provisioned but left empty for this capstone —
# in production it would hold a dedicated log-archive / audit account;
# here the management account plays that role to fit the time budget.

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "development" {
  name      = "Development"
  parent_id = local.root_id
}

# --- Move the existing workload account into Production ------------------
# This account already exists (created via the console during the SSO
# tutorial), so it must be imported before applying:
#
#   terraform import aws_organizations_account.workload 379549361194
#
# Once imported, changing parent_id below and re-applying calls
# Organizations' MoveAccount under the hood — Terraform manages the move,
# not a one-off CLI command.

resource "aws_organizations_account" "workload" {
  name      = "Training"
  email     = "weresamx@gmail.com"
  parent_id = aws_organizations_organizational_unit.production.id

  # role_name and iam_user_access_to_billing are deliberately omitted:
  # they're create-only attributes AWS never returns on read, so on an
  # imported account they always diff as "unknown" and (being ForceNew)
  # would make Terraform try to destroy and recreate the real account.
  # Leaving them unset means Terraform only ever manages name/parent_id.

  # Never let `terraform destroy` actually close/remove the AWS account.

  # Never let `terraform destroy` actually close/remove the AWS account.
  lifecycle {
    prevent_destroy = true
  }
}