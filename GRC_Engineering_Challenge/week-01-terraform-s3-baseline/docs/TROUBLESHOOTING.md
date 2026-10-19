# Troubleshooting log: Week 1 GRC engineering lab

This describes **issues actually encountered during the lab**, what was observed, and what resolved them. It separates confirmed observations from inferred causes. Use approved access and Regions; don't circumvent an organization's security policies.


## 1. AWS CLI authenticated, but Terraform could not find credentials

**Symptom:** `No valid credential sources found` followed by an EC2 instance-metadata fallback error.

**Confirmed clue:** `aws configure list --profile default` reported `login` as the access-key/secret-key source, while `aws sts get-caller-identity --profile default` succeeded.

**Resolution in this environment:** Add a local credential-process profile to `~/.aws/config`:

```ini
[profile terraform-lab]
region = us-east-2
credential_process = aws configure export-credentials --profile default --format process
```

Set `$env:AWS_PROFILE = "terraform-lab"` in PowerShell and test `aws sts get-caller-identity --profile terraform-lab`. The project uses AWS provider ~>5.x; support may differ with other provider versions. Do not export long-lived credentials into Terraform files.

**Lesson:** SDK/provider support may lag behind AWS CLI login methods. Authentication in one tool does not guarantee another can read the same credential source.

## 2. S3 bucket creation denied by an SCP

**Symptom:** `AccessDenied ... not authorized to perform s3:CreateBucket ... with an explicit deny in a service control policy` when deploying to `us-east-1`.

**Investigation:** The organization's management account was different from the Terraform project's account. AWS Settings identified the project-assigned Region as `us-east-2` (Ohio), while `terraform.tfvars` specified `us-east-1` (N. Virginia).

**Resolution:** Change `region = "us-east-2"`, generate **a new plan**, review, and deploy. The deployment then succeeded in Ohio.

**Evidence limitation:** We did *not* inspect the SCP statement, so this strongly suggests a Region restriction but does not prove the exact policy condition. SCP denies cannot be overridden by IAM allows; use the organization's approved Region and access path.

## 3. ACL instructions disagreed with AWS's recommended logging mechanism

**Original requirement:** Configure `aws_s3_bucket_ownership_controls` + `log-delivery-write` ACL + `aws_s3_bucket_logging`.

**Research finding:** AWS recommends a bucket policy for S3 log delivery. With `BucketOwnerEnforced`, ACLs are disabled, so an ACL grant is not appropriate.

**Resolution:** Grant `s3:PutObject` to the service principal `logging.s3.amazonaws.com` on the log bucket's `logs/*` prefix. Constrain by `aws:SourceArn` (primary bucket) and `aws:SourceAccount` (the current account). Explicitly set `BucketOwnerEnforced` and make logging depend on the policy and ownership controls.

**External validation:** The lab instructor agreed and indicated the next lab revision would use bucket policies. That is a planned update, not evidence that the revised material is already published.

See [architecture decision](ARCHITECTURE_DECISION.md).

## 4. Terraform `Invalid index` with `config.rule[0]`

**Symptom:** `Elements of a set are identified only by their value ...`, encountered in the `encryption_algorithms` output.

**Cause:** In the provider schema, nested encryption `rule` / default encryption blocks are sets, not numerically indexed lists.

**Resolution:** Use `one(one(config.rule).apply_server_side_encryption_by_default).sse_algorithm` in the output `for` expression. JSON plan blocks may appear as arrays; HCL provider types and JSON representations aren't interchangeable.

## 5. `BucketNotEmpty` during destroy

**Symptom:** Primary bucket deletion succeeded but the logging bucket could not be deleted because it contained access logs. Terraform state showed `force_destroy = false` for the logging bucket.

**Cause and lesson:** `force_destroy` is false by default, and changing a Terraform configuration file alone does not update the resource's stored state. A **successful apply of the flag** is required before destroy for an existing bucket. S3 may also deliver delayed logs after earlier requests.

**Resolution in this completed lab:** The remaining lab log bucket was manually emptied and deleted. For future *disposable* deployments, this version offers the optional `allow_force_destroy` variable (false by default), which must be applied before destroy. Never use force deletion on real audit evidence without an approved retention and disposal process.


