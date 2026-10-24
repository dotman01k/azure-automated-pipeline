import unittest
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[1]
class GitHubDeploymentContracts(unittest.TestCase):
 def setUp(self):
  self.flow=yaml.load((ROOT/'.github/workflows/deploy.yml').read_text(),Loader=yaml.BaseLoader)
 def test_only_manual_dispatch_and_main(self):
  self.assertEqual(list(self.flow['on']),['workflow_dispatch'])
  guard=self.flow['jobs']['validate']['if']
  self.assertIn("refs/heads/main",guard)
  self.assertIn("GH_DEPLOY_ENABLED == 'true'",guard)
 def test_all_services_selectable(self):
  choices=self.flow['on']['workflow_dispatch']['inputs']['service']['options']
  self.assertEqual(sorted(choices),sorted(p.name for p in (ROOT/'services').iterdir()))
 def test_apply_requires_plan_and_separate_environment(self):
  jobs=self.flow['jobs'];self.assertEqual(jobs['apply']['needs'],'plan')
  self.assertIn("inputs.operation == 'apply'",jobs['apply']['if'])
  self.assertTrue(jobs['plan']['environment']['name'].endswith('-plan'))
  self.assertTrue(jobs['apply']['environment']['name'].endswith('-apply'))
 def test_only_encrypted_artifact_uploaded(self):
  steps=self.flow['jobs']['plan']['steps']
  upload=next(x for x in steps if x.get('uses','').startswith('actions/upload-artifact@'))
  self.assertTrue(upload['with']['path'].endswith('/plan.enc'))
  self.assertEqual(upload['with']['retention-days'],'1')
  self.assertEqual(len([x for x in steps if x.get('uses','').startswith('actions/upload-artifact@')]),1)
 def test_oidc_and_platform_selection(self):
  for name in ['plan','apply']:
   job=self.flow['jobs'][name]
   self.assertEqual(job['permissions']['id-token'],'write')
   step=next(x for x in job['steps'] if 'Invoke-Terraform.ps1' in x.get('run',''))
   self.assertIn('-Platform GitHubActions',step['run'])
   self.assertNotIn('${{ inputs.',step['run'])
  self.assertNotIn('permissions',self.flow['jobs']['validate'])
 def test_concurrency_does_not_cancel_active_apply(self):
  self.assertEqual(self.flow['concurrency']['cancel-in-progress'],'false')
  self.assertIn('inputs.service',self.flow['concurrency']['group'])
  self.assertIn('inputs.environment',self.flow['concurrency']['group'])
 def test_actions_are_immutable(self):
  for job in self.flow['jobs'].values():
   for step in job['steps']:
    if 'uses' in step:self.assertRegex(step['uses'],r'^[\w/-]+@[0-9a-f]{40}$')
