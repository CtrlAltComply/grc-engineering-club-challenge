#!/usr/bin/env python3
"""Read-only checks of selected Week 1 controls in Terraform plan JSON.

Usage: python scripts/check_plan.py evidence/plan.json
This inspects PLANNED settings only; a complete log policy can be unknown before apply.
"""
import json
import sys
from pathlib import Path


def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('evidence/plan.json')
    try:
        plan = json.loads(path.read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as exc:
        print(f'ERROR: Cannot read JSON plan: {exc}', file=sys.stderr)
        return 2

    resources = {r['address']: r for r in plan.get('resource_changes', [])}
    check_results = []

    def record(mapping, name, passed, detail):
        check_results.append((mapping, name, passed, detail))

    def after(address):
        resource = resources.get(address, {})
        change = resource.get('change', {})
        if change.get('actions', []) == ['delete']:
            return {}
        return change.get('after') or {}

    for bucket in ('primary', 'log'):
        config = after(f'aws_s3_bucket_server_side_encryption_configuration.encryption["{bucket}"]')
        try:
            encryption = config['rule'][0]['apply_server_side_encryption_by_default'][0]['sse_algorithm']
        except (KeyError, IndexError, TypeError):
            encryption = None
        record('SC-28', f'{bucket} default SSE', encryption == 'AES256', f'algorithm={encryption!r}')

        pab = after(f'aws_s3_bucket_public_access_block.public_access["{bucket}"]')
        flags = ('block_public_acls','ignore_public_acls','block_public_policy','restrict_public_buckets')
        record('AC-3', f'{bucket} public access block', all(pab.get(flag) is True for flag in flags),
               ', '.join(f'{flag}={pab.get(flag)!r}' for flag in flags))

        tags = after(f'aws_s3_bucket.{bucket}').get('tags_all') or {}
        expected = {'Project':plan.get('variables', {}).get('project_name', {}).get('value'),
                    'Environment':plan.get('variables', {}).get('environment', {}).get('value'),
                    'ManagedBy':'Terraform','ComplianceScope':'NIST-800-53'}
        record('CM-6', f'{bucket} required tags', all(tags.get(k)==v for k,v in expected.items()),
               f'tags={tags}')

    versioning = after('aws_s3_bucket_versioning.primary').get('versioning_configuration') or []
    status = versioning[0].get('status') if versioning else None
    record('CM-6','primary versioning', status=='Enabled',f'status={status!r}')

    logging = after('aws_s3_bucket_logging.primary')
    record('AU-3','planned logging prefix', logging.get('target_prefix')=='logs/',
           f'prefix={logging.get("target_prefix")!r}; actual destination may be unknown until apply')

    own = (after('aws_s3_bucket_ownership_controls.logging').get('rule') or [])
    mode = own[0].get('object_ownership') if own else None
    record('AU-3','log bucket ownership',mode=='BucketOwnerEnforced',f'ownership={mode!r}')

    failed = 0
    for mapping,name,passed,detail in check_results:
        label = 'PASS' if passed else 'FAIL'
        failed += not passed
        print(f'{label:<5} {mapping:<7} {name}: {detail}')
    print("\nNot evaluated by this plan-only checker: the rendered log-bucket policy/ARNs, live AWS state, and actual log delivery.")
    print(f"\nPlan checks: {len(check_results)-failed}/{len(check_results)} passed")
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
