# Lock the origin buckets down: no public access of any kind.
resource "aws_s3_bucket_public_access_block" "site" {
  for_each = toset(var.domains)
  bucket   = data.aws_s3_bucket.site[each.value].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Grant read access only to this bucket's CloudFront distribution (via OAC).
# A service-principal policy with a SourceArn condition is not treated as
# "public", so it coexists with the public access block above.
resource "aws_s3_bucket_policy" "site" {
  for_each = toset(var.domains)
  bucket   = data.aws_s3_bucket.site[each.value].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${data.aws_s3_bucket.site[each.value].arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.site[each.value].arn
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.site]
}
