# CNAME records to add at Hover for ACM certificate validation.
output "acm_validation_records" {
  description = "Add each of these as a CNAME at Hover to validate the certificate."
  value = {
    for o in aws_acm_certificate.site.domain_validation_options :
    o.domain_name => {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  }
}

# After validation, point each site's CNAME at Hover to its CloudFront domain.
output "cloudfront_domains" {
  description = "Repoint each Hover CNAME (www, resume) to its CloudFront domain."
  value       = { for d, dist in aws_cloudfront_distribution.site : d => dist.domain_name }
}

# Needed as GitHub Actions secrets for the deploy invalidation step.
output "cloudfront_distribution_ids" {
  description = "Set as repo secrets CLOUDFRONT_WWW_ID / CLOUDFRONT_RESUME_ID."
  value       = { for d, dist in aws_cloudfront_distribution.site : d => dist.id }
}
