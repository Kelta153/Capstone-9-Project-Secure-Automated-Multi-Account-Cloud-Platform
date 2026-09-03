#!/usr/bin/env bash
set -euo pipefail

# One-time, idempotent: enables AWS CloudTrail as a trusted service in
# Organizations. Required before an org-wide CloudTrail trail can be
# created. Safe to re-run.

PROFILE="${1:-mgmt}"

echo "Enabling CloudTrail trusted access for Organizations (profile: ${PROFILE})..."
aws organizations enable-aws-service-access \
  --service-principal cloudtrail.amazonaws.com \
  --profile "${PROFILE}"

echo "Current trusted services:"
aws organizations list-aws-service-access-for-organization \
  --profile "${PROFILE}" \
  --query "EnabledServicePrincipals[].ServicePrincipal" \
  --output table