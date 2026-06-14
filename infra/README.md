# Infrastructure (HTTPS via CloudFront + ACM)

Terraform for serving `www.guyhf.com` and `resume.guyhf.com` over HTTPS:
an ACM certificate (us-east-1) and one CloudFront distribution per domain in
front of the existing — now private — S3 buckets, read via Origin Access
Control. See [`../docs/adr/0002-https-via-cloudfront-oac.md`](../docs/adr/0002-https-via-cloudfront-oac.md).

DNS is at **Hover**, not Route 53, so certificate validation and the final
CNAME repoint are manual. The order below keeps the live site up the whole time:
the buckets are not locked down until DNS already points at CloudFront.

## One-time bootstrap

The state bucket can't manage itself:

```sh
aws s3api create-bucket --bucket guyhf-tfstate --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2
aws s3api put-bucket-versioning --bucket guyhf-tfstate \
  --versioning-configuration Status=Enabled
terraform -chdir=infra init
```

## Step 1 — Certificate

```sh
terraform -chdir=infra apply -target=aws_acm_certificate.site
terraform -chdir=infra output acm_validation_records
```

Add the printed CNAME record(s) at Hover. ACM issues the cert once they resolve
(minutes to ~an hour).

## Step 2 — CloudFront (site stays live)

Create the distributions + OAC + the CloudFront-read bucket policy, but **not**
the public-access lockdown yet. The buckets stay publicly readable (via existing
object ACLs), so the current HTTP site keeps serving while CloudFront comes up:

```sh
terraform -chdir=infra apply \
  -target=aws_acm_certificate_validation.site \
  -target=aws_cloudfront_origin_access_control.site \
  -target=aws_cloudfront_distribution.site \
  -target=aws_s3_bucket_policy.site

terraform -chdir=infra output cloudfront_domains
```

## Step 3 — Repoint DNS at Hover

For each domain, change its Hover CNAME to the matching CloudFront domain from
`cloudfront_domains` (e.g. `www` → `dxxxx.cloudfront.net`). Wait for propagation,
then verify:

```sh
curl -sSI https://www.guyhf.com/        | head -1   # 200 over TLS
curl -sSI http://www.guyhf.com/         | head -1   # 301 -> https
curl -sSI https://resume.guyhf.com/     | head -1
```

## Step 4 — Lock the buckets down

Now that traffic flows through CloudFront, apply the rest (the public-access
block). After this, only CloudFront can read the buckets:

```sh
terraform -chdir=infra apply
```

## Step 5 — Switch the deploy to private buckets

In `.github/workflows/ci.yml` (see the PHASE 4 comment block there):

1. Remove `--acl public-read` from both `aws s3 sync` steps — it will now *fail*
   against the locked-down buckets.
2. Add a CloudFront invalidation after each sync, using the IDs from
   `terraform -chdir=infra output cloudfront_distribution_ids`.
3. Add repo secrets `CLOUDFRONT_WWW_ID` and `CLOUDFRONT_RESUME_ID`.

Land these in one commit. Done — the site is HTTPS end to end.
