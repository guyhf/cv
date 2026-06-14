# Dedicated IAM user for CI/CD deploys. Reusable later: attach additional
# managed policies to this user for other automation. The policy below stays
# least-privilege for publishing this site.

data "aws_caller_identity" "current" {}

resource "aws_iam_user" "deploy" {
  name = var.deploy_user_name
  tags = {
    purpose = "ci-deploy"
  }
}

# NOTE: the secret access key is stored in Terraform state. Keep state private
# (it lives in the encrypted S3 backend). Retrieve the secret with:
#   terraform -chdir=infra output -raw deploy_secret_access_key
resource "aws_iam_access_key" "deploy" {
  user = aws_iam_user.deploy.name
}

resource "aws_iam_policy" "deploy" {
  name        = "${var.deploy_user_name}-site"
  description = "Publish the static site to its S3 buckets and invalidate CloudFront."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListSiteBuckets"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [for d in var.domains : "arn:aws:s3:::${d}"]
      },
      {
        Sid    = "WriteSiteObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [for d in var.domains : "arn:aws:s3:::${d}/*"]
      },
      {
        Sid      = "InvalidateCloudFront"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "deploy" {
  user       = aws_iam_user.deploy.name
  policy_arn = aws_iam_policy.deploy.arn
}

output "deploy_access_key_id" {
  description = "Set as the GitHub Actions secret AWS_ACCESS_KEY_ID."
  value       = aws_iam_access_key.deploy.id
}

output "deploy_secret_access_key" {
  description = "Set as the GitHub Actions secret AWS_SECRET_ACCESS_KEY (sensitive; in state)."
  value       = aws_iam_access_key.deploy.secret
  sensitive   = true
}
