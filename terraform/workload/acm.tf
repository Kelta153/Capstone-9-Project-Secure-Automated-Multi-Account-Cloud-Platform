resource "tls_private_key" "alb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb" {
  private_key_pem = tls_private_key.alb.private_key_pem

  subject {
    common_name  = "capstone9-alb.internal"
    organization = "Capstone 9"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# ACM supports importing certificates as well as issuing publicly-validated
# ones. With no domain available for DNS/email validation, we import a
# Terraform-generated self-signed cert instead — the ALB genuinely
# terminates TLS via an ACM-managed certificate and the mechanism is real;
# only the trust chain is self-issued, which browsers will flag (documented
# limitation, noted in the report).
resource "aws_acm_certificate" "alb" {
  private_key      = tls_private_key.alb.private_key_pem
  certificate_body = tls_self_signed_cert.alb.cert_pem

  tags = {
    Project = var.project_prefix
  }
}