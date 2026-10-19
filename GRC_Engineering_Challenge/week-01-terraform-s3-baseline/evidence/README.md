# Evidence disclosure and interpretation

**`plan.json` is a sanitized educational sample**, derived from a real Terraform plan but **not** an unmodified Terraform export. Real AWS account IDs and bucket-specific suffixes were replaced with consistent synthetic values, and the original `prior_state` was omitted. An `x_portfolio_redaction` metadata field records this transformation.

This preserves meaningful Terraform plan structure (`resource_changes`, `planned_values`, `configuration`, etc.) for learning and control verification, but it cannot act as cryptographic proof of the original deployment. It is also **not** a binary plan to apply.

`verification-summary.json` and `verification-report.md` describe point-in-time AWS observations confirmed during the lab. Raw AWS account-specific API evidence, Terraform state, saved executable plans, private credentials, and access-log contents are deliberately excluded. The deployed infrastructure was subsequently destroyed.

Use `python scripts/check_plan.py evidence/plan.json` from the project root to assess selected planned security settings. For an actual deploy, export a **new** private Terraform plan and query the live AWS APIs.
