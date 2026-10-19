# GRC Engineering Challenge

**Building security controls that can be implemented, tested, enforced, and supported by evidence.**

This repository documents my progress through the **GRC Engineering Club's six-week GRC Engineering Challenge**. The goal is to move beyond describing controls in policies and spreadsheets to engineering controls into cloud infrastructure, evaluating them with code, and producing evidence that others can independently verify.

The project follows a connected workflow: **secure infrastructure → policy-as-code → CI enforcement → evidence integrity → cloud-native monitoring → assessor-ready control mapping**.

> **Current progress:** Week 1 completed and verified · Week 2 in progress · Weeks 3–6 planned.
>
> This is a hands-on learning project. The controls are mapped to NIST SP 800-53, but individual lab checks do **not** constitute an assessment of full NIST compliance or continuous monitoring.

## Challenge roadmap

| Week | Focus | Planned implementation and evidence | Status |
| --- | --- | --- | --- |
| **01** | **Infrastructure as Code** | Terraform-managed AWS S3 security baseline; JSON plan and live AWS verification for SC-28, AC-3, CM-6, and AU-3/AU-6. | **✅ Complete** |
| **02** | **Policy-as-Code** | Open Policy Agent (OPA)/Rego rules for SC-28 encryption, AC-3 public-access restrictions, and CM-6 tags; six unit-test cases and Conftest evaluation against the Week 1 plan. | **🚧 In progress** |
| **03** | **Continuous Integration Gate** | GitHub Actions pull-request checks that evaluate Terraform plans against the Rego policies, block violations, and upload results as evidence. | Planned |
| **04** | **Evidence Integrity & Chain of Custody** | SHA-256 hashing and keyless Cosign/Sigstore signing of evidence bundles, with verification and tamper-detection tests. | Planned |
| **05** | **Cloud-Native Monitoring** | AWS CloudTrail log-file validation and AWS Security Hub findings mapped to AU-2, AU-10, AU-12, RA-5, and SI-4; protected evidence capture and cleanup. | Planned |
| **06** | **OSCAL & Portfolio Case Study** | NIST OSCAL component definition and profile connecting implemented controls to evidence, followed by an end-to-end case study. | Planned |

## Week 1: Secure S3 baseline — completed

**[Explore the Week 1 implementation](week-01-terraform-s3-baseline/)**

Implemented a reusable Terraform configuration for a **primary data bucket** and a **dedicated access-log bucket** in AWS. The lab addressed four primary control areas (with AU-3 and AU-6 grouped together) and five specific configuration requirements:

| Control | NIST SP 800-53 name | Week 1 implementation | Verification |
| --- | --- | --- | --- |
| **SC-28** | Protection of Information at Rest | Default AES-256 server-side encryption on both S3 buckets | Live AWS API checks |
| **AC-3** | Access Enforcement | All four S3 Block Public Access flags enabled on both buckets | Live AWS API checks |
| **CM-6** | Configuration Settings | Versioning enabled on the primary bucket | Live AWS API check |
| **CM-6** | Configuration Settings | Required `Project`, `Environment`, `ManagedBy`, and `ComplianceScope` tags | Live AWS API checks |
| **AU-3 / AU-6** | Audit Record Content / Audit Record Review, Analysis, and Reporting | Server access logging to a dedicated bucket, with a least-privilege destination bucket policy and `BucketOwnerEnforced` ownership | Logging settings, policy/ownership checks, and observed delivery of log objects |

**Result:** The five lab requirements passed point-in-time verification. Terraform plan JSON and AWS CLI outputs were collected as evidence, and the lab infrastructure was subsequently removed to avoid leaving resources running.

### Technical decisions and lessons learned

- **S3 access logging permissions:** I researched AWS's bucket-policy-based log delivery guidance and implemented permissions for `logging.s3.amazonaws.com`, scoped to the destination prefix, source bucket ARN, and source AWS account. I discussed the difference from the lab's ACL-based instructions with the instructor; the conversation informed a planned lab update.
- **AWS organization restrictions:** An initial `s3:CreateBucket` request in `us-east-1` was explicitly denied by an AWS Organizations service control policy (SCP). Deployment succeeded after aligning Terraform with the AWS project's assigned `us-east-2` Region. The underlying SCP statement was not available for inspection.
- **AWS credential integration:** The AWS CLI's newer login-based authentication worked in the CLI but was not directly consumed by the Terraform AWS provider used for this lab. A dedicated `credential_process` profile bridged the tools.
- **Evidence quality:** The Terraform plan documents intended configuration; live AWS API responses and observed S3 access-log delivery provide separate, point-in-time verification.

For reproducible setup instructions, evidence details, troubleshooting, and the architecture decision, see the [Week 1 README](week-01-terraform-s3-baseline/) and its `docs/` directory.

## Week 2: Policy-as-Code — in progress

The next stage is turning Week 1's security requirements into **automated, repeatable tests**, using Open Policy Agent (OPA), Rego, and Conftest. The work will assess a Terraform plan for:

- **SC-28:** Missing S3 encryption configurations.
- **AC-3:** Missing or incomplete S3 Block Public Access settings.
- **CM-6:** Missing required tags on taggable resources.

The planned verification includes **six unit-test cases** (a passing and failing case for each policy), followed by running the policies against the saved Week 1 plan. Results and source code will be added when implemented and tested.

## Repository structure

```text
grc-engineering-challenge/
├── README.md                         # Challenge overview and progress
├── .gitignore                        # Keep local state and secrets out of Git
└── week-01-terraform-s3-baseline/    # Completed Week 1 portfolio project
    ├── README.md
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── evidence/                     # Sanitized examples / verification summary
    └── docs/                         # Troubleshooting and design rationale

# Week 2 and later directories will be added as work is completed.
```

## How to review this work

1. **Start with [Week 1](week-01-terraform-s3-baseline/)** to inspect the Terraform configuration and the security controls it implements.
2. Review the **sanitized Terraform plan evidence** and verification summary in the Week 1 `evidence/` folder. These are illustrative portfolio artifacts; the private, original AWS evidence is not published.
3. Read the Week 1 **troubleshooting notes and architecture decision** to understand why particular configurations were chosen and how deployment issues were resolved.
4. Return as the challenge progresses for policy tests, CI results, signed evidence, and OSCAL mappings.

## Tools and standards

**Currently used:** Terraform, AWS S3, AWS CLI, JSON, NIST SP 800-53.

**Planned for later weeks:** Open Policy Agent (Rego), Conftest, GitHub Actions, Cosign/Sigstore, AWS CloudTrail, AWS Security Hub, NIST OSCAL, and compliance-trestle.

## Security and publishing note

This public repository contains **sanitized examples and documentation**—not live credentials or unrestricted access to an AWS environment. Terraform state, credential files, private access logs, account-specific identifiers, and unsanitized evidence are excluded. The `evidence/plan.json` file in the public Week 1 folder is anonymized; it should not be mistaken for the original unmodified execution plan.

---

*Following the GRC Engineering Club's #GRCEngClubChallenge. Progress and findings reflect my own hands-on implementation and verification.*
