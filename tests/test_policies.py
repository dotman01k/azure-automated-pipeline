import copy,importlib.util,json,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def module(name):
 spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/f'{name}.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
policy=module('plan_policy');inputs=module('validate_inputs')
class InputTests(unittest.TestCase):
 def setUp(self):self.v=json.loads((ROOT/'environments/dev/terraform.tfvars.json').read_text())
 def test_dev(self):inputs.validate(self.v)
 def test_prod(self):inputs.validate(json.loads((ROOT/'environments/prod/terraform.tfvars.json').read_text()))
 def test_overlap(self):
  self.v['bastion_cidr']=self.v['workload_cidr']
  with self.assertRaises(ValueError):inputs.validate(self.v)
 def test_small_bastion(self):
  self.v['bastion_cidr']='10.30.0.0/27'
  with self.assertRaises(ValueError):inputs.validate(self.v)
 def test_outside_vnet(self):
  self.v['workload_cidr']='10.99.0.0/24'
  with self.assertRaises(ValueError):inputs.validate(self.v)
 def test_password_in_source(self):
  self.v['admin_password']='example'
  with self.assertRaises(ValueError):inputs.validate(self.v)
 def test_example_cannot_deploy(self):
  with self.assertRaises(ValueError):inputs.validate(self.v,True)
 def test_computer_name(self):
  self.v['computer_name']='much-too-long-computer-name'
  with self.assertRaises(ValueError):inputs.validate(self.v)
 def test_disk(self):
  self.v['os_disk_size_gb']=32
  with self.assertRaises(ValueError):inputs.validate(self.v)
class PlanTests(unittest.TestCase):
 def plan(self,actions):return {'complete':True,'resource_changes':[{'address':'vm.test','mode':'managed','change':{'actions':actions}}]}
 def test_create(self):self.assertEqual(policy.inspect(self.plan(['create'])),1)
 def test_update(self):self.assertEqual(policy.inspect(self.plan(['update'])),1)
 def test_noop(self):self.assertEqual(policy.inspect(self.plan(['no-op'])),0)
 def test_delete(self):
  with self.assertRaises(ValueError):policy.inspect(self.plan(['delete']))
 def test_replace(self):
  with self.assertRaises(ValueError):policy.inspect(self.plan(['delete','create']))
 def test_unknown(self):
  with self.assertRaises(ValueError):policy.inspect(self.plan(['forget']))
 def test_incomplete(self):
  p=self.plan(['create']);p['complete']=False
  with self.assertRaises(ValueError):policy.inspect(p)
 def test_error(self):
  p=self.plan(['create']);p['errored']=True
  with self.assertRaises(ValueError):policy.inspect(p)
 def test_deferred(self):
  p=self.plan(['create']);p['deferred_changes']=[{}]
  with self.assertRaises(ValueError):policy.inspect(p)
