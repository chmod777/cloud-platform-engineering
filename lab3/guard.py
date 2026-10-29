"""Restrict operations to Lab 3 resources in its isolated state."""
import json
import sys

mode, filename = sys.argv[1:]
plan = json.load(open(filename))
allowed = {
    'google_artifact_registry_repository.api',
    'google_service_account.runtime',
    'google_cloud_run_v2_service.api[0]',
    *[f'google_project_service.apis["{api}"]' for api in (
        'run.googleapis.com', 'artifactregistry.googleapis.com', 'iam.googleapis.com')],
}
if plan.get('errored') or plan.get('complete') is False or ('resource_changes' not in plan and not ('planned_values' in plan and plan.get('applyable') is False)):
    sys.exit('Incomplete plan: rejected.')
for change in plan.get('resource_changes', []):
    actions = change['change']['actions']
    if actions == ['no-op']:
        continue
    if change['address'] not in allowed:
        sys.exit('Resource outside Lab 3: rejected.')
    permitted = [['delete']] if mode == 'clean' else [['create']]
    if actions not in permitted:
        sys.exit('Unexpected update or replacement: rejected. Review manually.')
    after = change['change'].get('after') or {}
    if after.get('project') not in (None, 'cloud-platform-engineering-hs'):
        sys.exit('Unexpected project: rejected.')
    if mode == 'prepare' and change['address'].startswith('google_cloud_run'):
        sys.exit('Deployment is not allowed during prepare.')
print('Plan scope and actions validated.')
