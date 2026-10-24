import json,unittest
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[1]
class PipelineContracts(unittest.TestCase):
 def test_shared_apply_guard(self):
  p=yaml.safe_load((ROOT/'azure-pipelines.yml').read_text())
  self.assertNotIn('extends',p)
  self.assertEqual([x['stage'] for x in p['stages']],['Validate','Plan','Apply'])
  self.assertIn('refs/heads/main',p['stages'][2]['condition'])
  self.assertEqual(p['stages'][2]['lockBehavior'],'sequential')
 def test_every_service_entry_point(self):
  for service in (ROOT/'services').iterdir():
   p=yaml.safe_load((service/'azure-pipelines.yml').read_text())
   self.assertEqual(p['trigger'],'none');self.assertEqual(p['pr'],'none')
   self.assertNotIn('extends',p)
   selected=next(x for x in p['parameters'] if x['name']=='service')
   self.assertEqual(selected['default'],service.name)
   self.assertEqual(selected['values'],[service.name])
   canonical=yaml.safe_load((ROOT/'azure-pipelines.yml').read_text())
   self.assertEqual(p['stages'],canonical['stages'])
   self.assertEqual(p['variables'],canonical['variables'])
 def test_selector_covers_all_services(self):
  p=yaml.safe_load((ROOT/'azure-pipelines.yml').read_text())
  names=next(x for x in p['parameters'] if x['name']=='service')['values']
  self.assertEqual(sorted(names),sorted(x.name for x in (ROOT/'services').iterdir()))
 def test_cluster_workload_security(self):
  rows=list(yaml.safe_load_all((ROOT/'services/aks/app/deployment.yaml').read_text()))
  dep=next(x for x in rows if x['kind']=='Deployment')
  pod=dep['spec']['template']['spec'];container=pod['containers'][0]
  self.assertTrue(pod['securityContext']['runAsNonRoot'])
  self.assertFalse(container['securityContext']['allowPrivilegeEscalation'])
  self.assertTrue(container['securityContext']['readOnlyRootFilesystem'])
  service=next(x for x in rows if x['kind']=='Service')
  self.assertEqual(service['spec']['type'],'ClusterIP')
 def test_batch_task_is_bounded(self):
  task=json.loads((ROOT/'services/batch/app/task.json').read_text())
  self.assertEqual(task['constraints']['maxWallClockTime'],'PT5M')
  self.assertEqual(task['constraints']['maxTaskRetryCount'],1)

 def test_refreshable_oidc_for_plan_and_apply(self):
  p=yaml.safe_load((ROOT/'azure-pipelines.yml').read_text())
  plan=p['stages'][1]['jobs'][0]['steps']
  apply=p['stages'][2]['jobs'][0]['strategy']['runOnce']['deploy']['steps']
  for steps in (plan,apply):
   task=next(x for x in steps if x.get('task')=='AzureCLI@2')
   self.assertEqual(task['env']['SYSTEM_ACCESSTOKEN'],'$(System.AccessToken)')
   self.assertEqual(task['env']['SYSTEM_OIDCREQUESTURI'],'$(System.OidcRequestUri)')
   self.assertEqual(task['env']['ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID'],'$(AZURE_SERVICE_CONNECTION_ID)')
   self.assertTrue(task['inputs']['addSpnToEnvironment'])
