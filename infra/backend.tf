# Remote state in S3 with native lockfile (Terraform >= 1.10, no DynamoDB needed).
#
# Bootstrap once before `terraform init` (the state bucket cannot manage itself):
#
#   aws s3api create-bucket --bucket guyhf-tfstate --region us-west-2 \
#     --create-bucket-configuration LocationConstraint=us-west-2
#   aws s3api put-bucket-versioning --bucket guyhf-tfstate \
#     --versioning-configuration Status=Enabled
#
# Then change the bucket name below if you chose a different one.
terraform {
  backend "s3" {
    bucket       = "guyhf-tfstate"
    key          = "cv/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
