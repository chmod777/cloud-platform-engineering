"""Limiter les opérations aux ressources du LAB 3 dans son état isolé."""
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
    sys.exit('Plan incomplet : refus.')
for change in plan.get('resource_changes', []):
    actions = change['change']['actions']
    if actions == ['no-op']:
        continue
    if change['address'] not in allowed:
        sys.exit('Ressource hors LAB 3 : refus.')
    permitted = [['delete']] if mode == 'clean' else [['create']]
    if actions not in permitted:
        sys.exit('Modification/remplacement inattendu : refus. Examiner manuellement.')
    after = change['change'].get('after') or {}
    if after.get('project') not in (None, 'cloud-platform-engineering-hs'):
        sys.exit('Projet inattendu : refus.')
    if mode == 'prepare' and change['address'].startswith('google_cloud_run'):
        sys.exit('Déploiement interdit pendant prepare.')
print('Périmètre et actions du plan validés.')
