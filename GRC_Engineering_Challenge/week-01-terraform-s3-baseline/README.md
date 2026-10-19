# Terraform S3 Security Baseline | GRC Engineering — Week 1

> **Portfolio summary:** This Terraform configuration implements NIST SP 800-53-aligned **SC-28 (Protection of Information at Rest)**, **AC-3 (Access Enforcement)**, **CM-6 (Configuration Settings)**, and **AU-3 / AU-6 (Audit Records / Audit Review support)** for an AWS S3 primary data bucket and a separate access-log destination. It produces machine-readable Terraform plan evidence and supports independent AWS CLI verification. 

## Overview

This hands-on lab was deployed and verified in a development AWS environment. The primary bucket stores data; a separate encrypted bucket receives S3 server access logs. The log destination uses a narrowly scoped **bucket policy**, **not** a legacy `log-delivery-write` ACL. The policy permits only `s3:PutObject` by `logging.s3.amazonaws.com`, constrained to `logs/*`, the primary source bucket ARN, and the account ID.

```text
Terraform (AWS provider)
    ├── S3 primary bucket ── server access logs ──► S3 log bucket (logs/*)
    │     ├── AES256 default encryption                ├── AES256 encryption
    │     ├── Versioning: Enabled                      ├── Public access blocked
    │     └── Four public-access flags: true           ├── BucketOwnerEnforced
    └── Four tags on taggable resources               └── Scoped S3 logging service policy
```

## Security requirements and implementation

| Mapping | Lab requirement | Terraform resource | What is verified |
| --- | --- | --- | --- |
| SC-28 | SSE-S3 default encryption on both buckets | `aws_s3_bucket_server_side_encryption_configuration` (for_each) | `AES256` for both |
| AC-3 | Block all four public access vectors | `aws_s3_bucket_public_access_block` (for_each) | Four flags `true`, both buckets |
| CM-6 | Enable versioning for primary data | `aws_s3_bucket_versioning` | `Enabled` |
| CM-6 | Tag every supported resource | Provider `default_tags` | `Project`, `Environment`, `ManagedBy`, `ComplianceScope` |
| AU-3 / AU-6 | Send primary bucket request logs to an authorized destination | `aws_s3_bucket_logging`, `aws_s3_bucket_policy`, `aws_s3_bucket_ownership_controls` | `logs/` target, tightly scoped policy, observed log delivery |

**Scope caveats:** server access logging is *best effort*, not a complete security-audit solution. S3 versioning does not provide immutable retention. Terraform plan files show intended changes, while AWS API checks show deployed configuration at a point in time. Real compliance also needs governance, review, monitoring, and testing beyond this lab.

## Prerequisites

- Terraform >= 1.6, AWS provider ~> 5.x (versions locked in `.terraform.lock.hcl`)
- AWS CLI v2 with permission to create/configure/delete lab S3 buckets
- An AWS account/project with an **approved deployment Region** and appropriate organizational guardrails
- Windows PowerShell (examples below) or another shell with equivalent commands
- Python 3 for the optional plan-checking script

### AWS authentication (important for newer `aws login` setups)

Verify: `aws sts get-caller-identity --profile terraform-lab`.

For accounts whose AWS CLI uses `aws login`, older Terraform AWS providers may not read login-backed credentials directly. A local `~/.aws/config` profile can bridge them without placing access keys in Terraform:

```ini
[profile terraform-lab]
region = us-east-2
credential_process = aws configure export-credentials --profile default --format process
```

This assumes your existing `default` profile already authenticates successfully. **Do not commit `~/.aws/config` or export credential JSON to the repository.** Pick the profile appropriate to your own environment. See [Troubleshooting](docs/TROUBLESHOOTING.md).

## Run this project (PowerShell)

1. Make a private variable file from `terraform.tfvars.example`, then edit `region` for your approved AWS Region.

   ```powershell
   Copy-Item terraform.tfvars.example terraform.tfvars
   $env:AWS_PROFILE = "terraform-lab"
   terraform init
   terraform fmt -check
   terraform validate
   terraform plan -out=tfplan
   ```

2. Generate your **private** plan evidence after reviewing the plan. Never commit an unreviewed real plan or state.

   ```powershell
   New-Item -ItemType Directory -Force -Path evidence
   cmd /c "terraform show -json tfplan > evidence\plan.json"
   python scripts/check_plan.py evidence/plan.json
   ```

   On Windows PowerShell 5.1, using `cmd /c` avoids UTF-16 redirection for the Terraform JSON export. `check_plan.py` only examines the **planned** settings and explicitly treats unresolved logging policy fields as pending live verification.

3. When ready to deploy into your authorized sandbox, review `terraform show tfplan`, then use `terraform apply tfplan`. A saved plan is applied as-is; there is no second approval prompt. Do not reuse an old saved plan after changing input variables or Region.

4. ### 4. Verify deployed controls

After deploying the Terraform configuration, run the included `verify.sh` script to retrieve the actual AWS security settings.

This script builds upon the original GRC Engineering Club lab verification method by inspecting both buckets' encryption, public access protections, resource tags, primary bucket versioning, and S3 logging configuration.

Run from the Week 1 directory in a Bash-compatible terminal, such as Git Bash or WSL:

```bash
export AWS_PROFILE=terraform-lab
export AWS_REGION=us-east-2
bash ./verify.sh
```

Review the AWS API responses to confirm that the deployed configurations match the intended NIST 800-53 control requirements.

**Note:** This script retrieves live AWS configuration data but does not automatically determine PASS/FAIL or independently confirm successful log delivery.

For additional verification, inspect the logging bucket for delivered access log objects:

```bash
aws s3api list-objects-v2 \
  --bucket YOUR-LOG-BUCKET \
  --prefix logs/ \
  --region us-east-2 \
  --profile terraform-lab
```

Replace `YOUR-LOG-BUCKET` with your actual logging bucket name.

Because S3 server access logging is asynchronous and best-effort, log delivery may take time.

**Historical verification:** The Week 1 infrastructure was successfully deployed, independently verified, and subsequently destroyed. Live verification requires an active deployment.

**Note:** The committed public `evidence/plan.json` is an **anonymized representation** of the original plan, suitable for studying the schema and running the plan checks. It is not the original unmodified Terraform export, a deployable plan, or a cryptographically attested document. The original raw plan and AWS API evidence are intentionally excluded from this public package.

## Cleanup for disposable lab deployments

By default `allow_force_destroy = false`: this prevents accidental deletion of nonempty buckets. If log files or object versions remain, `terraform destroy` may fail with `BucketNotEmpty`.

After preserving evidence and confirming that the buckets contain *only disposable lab data*: 

```powershell
# Apply the state change before destroy; this is important for force_destroy.
terraform plan -var="allow_force_destroy=true" -out=cleanup.tfplan
terraform apply cleanup.tfplan
terraform destroy -var="allow_force_destroy=true"
terraform state list
```

Review **each** plan and destroy prompt carefully. `allow_force_destroy=true` can permanently remove all objects and versions. Do not use this setting casually with production data. S3 may deliver delayed access logs during cleanup; inspect remaining objects if destruction fails. See [Cleanup note](docs/TROUBLESHOOTING.md#6-bucketnotempty-during-destroy).

## Evidence, reproducibility, and limitations

- [`evidence/plan.json`](evidence/plan.json) — **public, anonymized sample** retaining Terraform's useful resource/change structure.
- [`evidence/verification-summary.json`](evidence/verification-summary.json) — privacy-safe summary of the reported live checks.
- [`evidence/verification-report.md`](evidence/verification-report.md) — project verification narrative and limitations.
- [`scripts/check_plan.py`](scripts/check_plan.py) — evaluates selected requirements against saved Terraform plan JSON, without AWS calls.
- [`scripts/verify-live.ps1`](scripts/verify-live.ps1) — checks configured controls directly via read-only AWS API requests (requires deployed buckets).
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — real issues from this lab, including AWS login authentication, SCP/Region restriction, Terraform set indexing, and cleanup.
- [`docs/ARCHITECTURE_DECISION.md`](docs/ARCHITECTURE_DECISION.md) — why I chose a bucket policy instead of the original lab's ACL method.

The Week 1 project is the foundation for later policy-as-code / evidence mapping labs. Keep the Terraform resource addresses and output names stable if downstream work references them. The public snapshot deliberately contains no local state, provider binaries, secret material, or real AWS account identifiers.

## Outcome

The lab reached successful deployment and point-in-time live verification of both buckets' encryption, both public-access blocks, primary versioning, four tags on both buckets, and the log destination's ownership and scoped permissions. Two access-log objects were observed under `logs/`, and one log file was inspected. **The lab resources were subsequently removed.**

### References

- [AWS S3 server access logging and bucket-policy recommendation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html)
- [Terraform AWS S3 bucket documentation (`force_destroy`)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
- [AWS CLI credential process](https://docs.aws.amazon.com/cli/latest/reference/configure/export-credentials.html)
- [HashiCorp issue: Terraform AWS provider and `aws login`](https://github.com/hashicorp/terraform-provider-aws/issues/45316)
