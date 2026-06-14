# Remote state in the existing shared state bucket, isolated under its own key.
# Native S3 lockfile (Terraform >= 1.10, no DynamoDB needed).
#
# If that bucket is not in us-west-2, set `region` to the bucket's region.
terraform {
  backend "s3" {
    bucket       = "guyhf-terraform-state"
    key          = "cv/terraform.tfstate"
    region       = "us-east-1" # region of the state bucket (site buckets are us-west-2)
    encrypt      = true
    use_lockfile = true
  }
}
