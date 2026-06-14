# One certificate in us-east-1 covering every served domain. The primary domain
# is the common name; the rest are subject-alternative names.
resource "aws_acm_certificate" "site" {
  provider    = aws.us_east_1
  domain_name = var.primary_domain
  subject_alternative_names = [
    for d in var.domains : d if d != var.primary_domain
  ]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation records must be created by hand at Hover (DNS is not in Route 53).
# `terraform output acm_validation_records` prints exactly what to add. Once the
# CNAMEs exist, this resource polls until ACM issues the certificate.
resource "aws_acm_certificate_validation" "site" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.site.arn

  timeouts {
    create = "60m"
  }
}
