import importlib.util,json,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('inputs',ROOT/'scripts/validate_inputs.py');inputs=importlib.util.module_from_spec(spec);spec.loader.exec_module(inputs)
SERVICES=['aks', 'app-service', 'batch', 'container-apps', 'container-instances', 'functions', 'service-fabric', 'storage', 'virtual-desktop', 'virtual-machines', 'vm-scale-sets']
class CollectionTests(unittest.TestCase):
 def test_service_inventory(self):
  self.assertEqual(sorted(p.name for p in (ROOT/'services').iterdir() if p.is_dir()),SERVICES)
 def test_secrets_are_declared(self):
  for s in SERVICES:
   p=ROOT/'services'/s
   m=json.loads((p/'project.json').read_text())
   self.assertEqual(m['service'],s)
   for env in ['dev','prod']:
    v=json.loads((p/'environments'/env/'terraform.tfvars.json').read_text())
    self.assertFalse(set(v)&set(m['secret_variables']))
 def test_app_service_wsgi(self):
  spec=importlib.util.spec_from_file_location('web',ROOT/'services/app-service/app/app.py');web=importlib.util.module_from_spec(spec);spec.loader.exec_module(web)
  for path,status in [('/','200 OK'),('/healthz','200 OK'),('/missing','404 Not Found')]:
   captured=[];body=web.application({'PATH_INFO':path},lambda s,h:captured.append(s))
   self.assertEqual(captured,[status]);self.assertEqual(json.loads(b''.join(body))['healthy'],status=='200 OK')
 def test_internet_cidr_rejected(self):
  v=json.loads((ROOT/'services/app-service/environments/dev/terraform.tfvars.json').read_text());v['allowed_cidrs']=['0.0.0.0/0']
  with self.assertRaises(ValueError):inputs.validate(v)
 def test_documentation_cidr_cannot_be_live(self):
  v=json.loads((ROOT/'services/app-service/environments/dev/terraform.tfvars.json').read_text());v['subscription_id']='9d046dba-8c48-4fb8-91cc-a6011d06348b'
  with self.assertRaises(ValueError):inputs.validate(v,True)

def make_contract(service,env):
 def test(self):
  v=json.loads((ROOT/'services'/service/'environments'/env/'terraform.tfvars.json').read_text());inputs.validate(v)
 return test
for service in SERVICES:
 for env in ['dev','prod']:setattr(CollectionTests,'test_contract_'+service.replace('-','_')+'_'+env,make_contract(service,env))
