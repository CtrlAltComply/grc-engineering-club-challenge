#!/usr/bin/env bash
# Read-only convenience check for a *deployed* Week 1 configuration.
set -euo pipefail
PROFILE="${AWS_PROFILE:-terraform-lab}"
REGION="${AWS_REGION:-us-east-2}"
primary="$(terraform output -raw bucket_name)"
log="$(terraform output -raw log_bucket_name)"
for bucket in "$primary" "$log"; do
  echo "=== $bucket: AES256 encryption ==="
  aws s3api get-bucket-encryption --bucket "$bucket" --profile "$PROFILE" --region "$REGION"
  echo "=== $bucket: public access block ==="
  aws s3api get-public-access-block --bucket "$bucket" --profile "$PROFILE" --region "$REGION"
  echo "=== $bucket: tags ==="
  aws s3api get-bucket-tagging --bucket "$bucket" --profile "$PROFILE" --region "$REGION"
done

echo "=== Primary versioning ==="
aws s3api get-bucket-versioning --bucket "$primary" --profile "$PROFILE" --region "$REGION"
echo "=== Primary log target ==="
aws s3api get-bucket-logging --bucket "$primary" --profile "$PROFILE" --region "$REGION"
echo "=== Log destination ownership / policy ==="
aws s3api get-bucket-ownership-controls --bucket "$log" --profile "$PROFILE" --region "$REGION"
aws s3api get-bucket-policy --bucket "$log" --profile "$PROFILE" --region "$REGION" --query Policy --output json

echo 'Review the AWS API responses above to confirm deployed control configurations.'