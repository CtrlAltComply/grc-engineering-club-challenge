# ADR-001: Bucket policies instead of canned log-delivery ACLs

**Status:** Accepted for Week 1 and future weeks  
**Scope:** Permission to deliver Amazon S3 server access logs into a dedicated S3 bucket

## Context

The lab's original instructions used `aws_s3_bucket_ownership_controls` together with an S3 `log-delivery-write` ACL. AWS now recommends **bucket-policy-based** authorization for server access logging and defaults new buckets to `BucketOwnerEnforced` (ACLs disabled).

The security outcome required by AU-3/AU-6 support is that the primary bucket's access logs are captured in a controlled destination. This does not prescribe a specific AWS permission implementation.

## Decision

Use `data.aws_iam_policy_document.logging` + `aws_s3_bucket_policy.logging` with:

- **Principal:** `logging.s3.amazonaws.com` only.
- **Action:** `s3:PutObject` only.
- **Resource:** objects under the dedicated log bucket's `logs/*` prefix only.
- **Conditions:** `aws:SourceArn` equals/matches primary bucket ARN, and `aws:SourceAccount` exactly matches the AWS account ID.
- **Ownership:** log bucket explicitly uses `BucketOwnerEnforced` and ACLs remain disabled.
- **Ordering:** `aws_s3_bucket_logging.primary` depends on the bucket policy and ownership controls.

## Alternatives

A canned `log-delivery-write` ACL can still enable logging if bucket ownership settings allow ACLs, but it is not AWS's recommended current approach and provides less fine-grained source scoping.

## Result / verification

The lab was deployed successfully, and AWS API queries confirmed policy content, ownership controls, logging target prefix, and two log objects delivered to the destination. 
The instructor confirmed the modern implementation would work with subsequent weeks and said the next lab revision would incorporate the feedback.

[Official AWS guidance](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html)
