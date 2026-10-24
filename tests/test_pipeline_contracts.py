import json,unittest
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[1]
class PipelineContracts(unittest.TestCase):
 def test_shared_apply_guard(self):
  p=yaml.safe_load((ROOT/'azure-pipelines.yml').read_text())
  self.assertNotIn('extends',p)
  self.assertEqual([x['stage'] for x in p['stages']],['TerraformInit','TerraformValidate','TerraformPlan','TerraformApply'])
  self.assertIn('refs/heads/main',p['stages'][3]['condition'])
  self.assertEqual(p['stages'][3]['lockBehavior'],'sequential')
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
  plan=p['stages'][2]['jobs'][0]['steps']
  apply=p['stages'][3]['jobs'][0]['strategy']['runOnce']['deploy']['steps']
  for steps in (plan,apply):
   task=next(x for x in steps if x.get('task')=='AzureCLI@2')
   self.assertEqual(task['env']['SYSTEM_ACCESSTOKEN'],'$(System.AccessToken)')
   self.assertEqual(task['env']['SYSTEM_OIDCREQUESTURI'],'$(System.OidcRequestUri)')
   self.assertEqual(task['env']['ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID'],'$(AZURE_SERVICE_CONNECTION_ID)')
   self.assertTrue(task['inputs']['addSpnToEnvironment'])

 def test_terraform_commands_are_visible_and_guarded(self):
  p=yaml.safe_load((ROOT/'azure-pipelines.yml').read_text())
  init=p['stages'][0]['jobs'][0]['steps']
  initialization=next(x['inputs']['script'] for x in init if x.get('displayName')=='Run terraform fmt and terraform init')
  self.assertIn('terraform init',initialization)
  self.assertIn('terraform fmt',initialization)
  validate=p['stages'][1]['jobs'][0]['steps']
  validation=next(x['inputs']['script'] for x in validate if x.get('displayName')=='Run terraform validate')
  self.assertIn('terraform validate',validation)
  for i,stage in enumerate(p['stages']):
   self.assertTrue(stage['displayName'].startswith(f'Stage {i+1}: Terraform '))
   if i:self.assertEqual(stage['dependsOn'],p['stages'][i-1]['stage'])
  plan=next(x for x in p['stages'][2]['jobs'][0]['steps'] if x.get('task')=='AzureCLI@2')['inputs']
  apply=next(x for x in p['stages'][3]['jobs'][0]['strategy']['runOnce']['deploy']['steps'] if x.get('task')=='AzureCLI@2')['inputs']
  self.assertEqual(plan['scriptLocation'],'inlineScript')
  self.assertLess(plan['inlineScript'].index('-Phase Prepare'),plan['inlineScript'].index('terraform init'))
  self.assertLess(plan['inlineScript'].index('terraform plan'),plan['inlineScript'].index('-Phase RecordPlan'))
  self.assertLess(apply['inlineScript'].index('-Phase VerifyPlan'),apply['inlineScript'].index('terraform apply'))
  self.assertIn('$artifactDirectory/platform.tfplan',apply['inlineScript'])
