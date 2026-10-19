output "bucket_name" {
  description = "Primary bucket name."
  value       = aws_s3_bucket.primary.id
}

output "bucket_arn" {
  description = "Primary bucket ARN."
  value       = aws_s3_bucket.primary.arn
}

output "log_bucket_name" {
  description = "Access logging destination bucket name."
  value       = aws_s3_bucket.log.id
}

# SC-28: Scalable, machine-readable encryption settings for every managed bucket.
# The provider represents these nested rules as sets, so use one(), not [0].
output "encryption_algorithms" {
  description = "Default SSE algorithms configured for all managed S3 buckets."
  value = {
    for name, config in aws_s3_bucket_server_side_encryption_configuration.encryption :
    name => one(one(config.rule).apply_server_side_encryption_by_default).sse_algorithm
  }
}
