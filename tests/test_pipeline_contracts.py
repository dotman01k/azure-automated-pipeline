import json,unittest
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[1]
class PipelineContracts(unittest.TestCase):
 def test_shared_apply_guard(self):
  p=yaml.safe_load((ROOT/'pipelines/compute.yml').read_text())
  self.assertEqual([x['stage'] for x in p['stages']],['Validate','Plan','Apply'])
  self.assertIn('refs/heads/main',p['stages'][2]['condition'])
  self.assertEqual(p['stages'][2]['lockBehavior'],'sequential')
 def test_every_service_entry_point(self):
  for service in (ROOT/'services').iterdir():
   p=yaml.safe_load((service/'azure-pipelines.yml').read_text())
   self.assertEqual(p['trigger'],'none');self.assertEqual(p['pr'],'none')
   self.assertEqual(p['extends']['parameters']['service'],service.name)
   self.assertTrue((service/p['extends']['template']).is_file())
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
