"""Credential-free input validation, plus live placeholder checks."""
import argparse,ipaddress,json,re,uuid
EXAMPLE='00000000-0000-0000-0000-000000000001'
def validate(v,live=False):
 subscription=str(uuid.UUID(v['subscription_id']))
 if live and subscription==EXAMPLE:raise ValueError('Replace the example subscription before live planning')
 if 'admin_password' in v:raise ValueError('Do not put administrator passwords in public tfvars')
 if 'vnet_cidr' in v:
  parent=ipaddress.ip_network(v['vnet_cidr'],strict=True)
  children=[ipaddress.ip_network(v[k],strict=True) for k in ['subnet_cidr','workload_cidr','bastion_cidr'] if k in v]
  if parent.version!=4 or any(not child.subnet_of(parent) for child in children):raise ValueError('Subnets must be inside the IPv4 VNet')
  if any(a.overlaps(b) for i,a in enumerate(children) for b in children[i+1:]):raise ValueError('Subnets overlap')
  if 'bastion_cidr' in v and ipaddress.ip_network(v['bastion_cidr']).prefixlen>26:raise ValueError('Bastion subnet must be /26 or larger')
 if 'computer_name' in v and not re.fullmatch(r'[a-zA-Z][a-zA-Z0-9-]{0,14}',v['computer_name']):raise ValueError('Invalid computer name')
 if 'os_disk_size_gb' in v and (type(v['os_disk_size_gb']) is not int or not 128<=v['os_disk_size_gb']<=1024):raise ValueError('Invalid disk size')
 if 'install_iis' in v and type(v['install_iis']) is not bool:raise ValueError('install_iis must be boolean')
 if 'allowed_cidrs' in v:
  if not v['allowed_cidrs']:raise ValueError('Supply explicit client CIDRs')
  for cidr in v['allowed_cidrs']:
   net=ipaddress.ip_network(cidr,strict=True)
   if net.version!=4 or net.prefixlen==0:raise ValueError('No internet-wide or IPv6 access in this baseline')
   if live and any(net.overlaps(ipaddress.ip_network(x)) for x in ['192.0.2.0/24','198.51.100.0/24','203.0.113.0/24']):raise ValueError('Replace documentation-only CIDRs')
 if live:
  if 'offline-example' in v.get('ssh_public_key',''):raise ValueError('Replace the offline test SSH key')
  if v.get('client_certificate_thumbprint','')=='A'*40:raise ValueError('Replace the example certificate thumbprint')
  for key in ['user_group_object_id','admin_group_ids','data_principal_id']:
   if key in v:
    ids=v[key] if isinstance(v[key],list) else [v[key]]
    if any(str(uuid.UUID(x)).startswith('00000000-0000-0000-0000-') for x in ids):raise ValueError('Replace example group IDs')
 return v
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('path');p.add_argument('--live',action='store_true');a=p.parse_args()
 with open(a.path,encoding='utf-8-sig') as f:validate(json.load(f),a.live)
 print('Environment contract passed')
