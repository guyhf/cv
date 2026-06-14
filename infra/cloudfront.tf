# Existing origin buckets (created and populated by the deploy pipeline).
data "aws_s3_bucket" "site" {
  for_each = toset(var.domains)
  bucket   = each.value
}

# AWS-managed cache policy tuned for static sites.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# One Origin Access Control per bucket; CloudFront signs origin requests with it.
resource "aws_cloudfront_origin_access_control" "site" {
  for_each                          = toset(var.domains)
  name                              = each.value
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# One distribution per domain.
resource "aws_cloudfront_distribution" "site" {
  for_each = toset(var.domains)

  enabled             = true
  is_ipv6_enabled     = true
  comment             = each.value
  aliases             = [each.value]
  default_root_object = "index.html"
  price_class         = var.price_class

  origin {
    origin_id                = "s3-${each.value}"
    domain_name              = data.aws_s3_bucket.site[each.value].bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site[each.value].id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${each.value}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
