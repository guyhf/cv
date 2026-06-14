variable "aws_region" {
  description = "Region of the existing S3 origin buckets."
  type        = string
  default     = "us-west-2"
}

variable "primary_domain" {
  description = "Primary site domain (the certificate's common name)."
  type        = string
  default     = "www.guyhf.com"
}

variable "domains" {
  description = "All domains served. Each must already have an S3 bucket of the same name."
  type        = list(string)
  default     = ["www.guyhf.com", "resume.guyhf.com"]
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100 = NA + EU, cheapest)."
  type        = string
  default     = "PriceClass_100"
}
