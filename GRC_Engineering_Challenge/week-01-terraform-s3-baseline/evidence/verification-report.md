# Week 1 — S3 Security Verification Report

**Environment:** Development; AWS Region `us-east-2`  
**Assessment date:** 2026-10-19  
**Evidence sources:** Terraform saved plan JSON, AWS CLI `s3api` responses, observed access-log objects  
**Reported outcome:** Five Week 1 lab requirements satisfied in point-in-time checks

## Objective and scope

Implement and verify selected technical safeguards on one primary S3 bucket and one dedicated logging bucket using Terraform. The controls are **aligned to**, but do not establish comprehensive compliance with, NIST SP 800-53.

| Control mapping | Control objective | Observed result | Outcome |
| --- | --- | --- | --- |
| SC-28 | Default SSE-S3 encryption on both buckets | Both reported `AES256` | PASS |
| AC-3 | Four S3 public-access-block settings per bucket | All four were true on both buckets | PASS |
| CM-6 | Primary S3 versioning | Primary reported `Enabled` | PASS |
| CM-6 | Standard asset tags | `Project`, `Environment`, `ManagedBy`, and `ComplianceScope` matched on both buckets | PASS |
| AU-3 / AU-6 | Server access logging and controlled log destination | `logs/` target, `BucketOwnerEnforced`, least-privilege bucket policy, two delivered log objects; sample log inspected | PASS for lab objective |

## Technical design

- Terraform uses `for_each` to apply a shared encryption and public-access baseline to both buckets.
- The primary bucket has versioning enabled; the log bucket is a separate destination.
- The AWS provider's `default_tags` supplies four consistent tags to supported resources.
- A logging bucket policy authorizes only the S3 log delivery service to write into `logs/*`, restricted to the primary bucket ARN and account ID.
- `BucketOwnerEnforced` keeps ACLs disabled; no legacy canned ACL grant is required.
- The logging resource explicitly depends on completed permissions and ownership settings.

## Evidence and verification approach

1. **Configuration intent:** `main.tf`, `variables.tf`, `outputs.tf`.
2. **Planned evidence:** Terraform plan exported in structured JSON; the public sample is anonymized.
3. **AWS configuration:** S3 API reads for encryption, public access, versioning, tags, bucket policy, object ownership, and the log destination.
4. **Observed behavior:** Two objects were observed under the `logs/` destination prefix. One sample log was opened. This confirms delivery occurred, but not that every request was captured.

## Implementation obstacles

- AWS CLI's newer `aws login` method required a `credential_process` bridge for the selected Terraform AWS provider.
- `s3:CreateBucket` was denied by an AWS Organizations SCP when the provider targeted `us-east-1`. The project was assigned to `us-east-2`; deploying there succeeded. The SCP statements were not inspected, so exact policy logic remains unconfirmed.
- The original ACL-based logging instructions were replaced with AWS's recommended bucket-policy-based approach after a review of provider guidance and a discussion with the instructor.
- Terraform output access needed `one()` because the provider's encryption rule uses set semantics.
- The log destination needed separate cleanup because it contained delivered access logs and `force_destroy` was recorded as `false`.

## Limitations and follow-up

- Server access logging is best-effort; AU-3/AU-6 full control satisfaction needs organization-specific requirements, review processes, and potentially complementary audit telemetry.
- The lab was **destroyed after evidence collection**; results describe the historical deployment, not current resources.
- Any public artifacts must remove real AWS account IDs, bucket identifiers, state, credentials, and raw access logs.
- Future weeks can build policy-as-code gates and structured assurance records from the saved, private plan evidence.

See `docs/TROUBLESHOOTING.md` and `docs/ARCHITECTURE_DECISION.md` for details.
