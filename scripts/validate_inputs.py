"""Check the public environment contract before Terraform contacts Azure."""
import argparse,ipaddress,json,re,uuid

def validate(v,live=False):
    subscription=uuid.UUID(v['subscription_id'])
    if live and str(subscription)=='00000000-0000-0000-0000-000000000001':
        raise ValueError('Replace the example subscription before live planning')
    parent=ipaddress.ip_network(v['vnet_cidr'],strict=True)
    app=ipaddress.ip_network(v['workload_cidr'],strict=True)
    bastion=ipaddress.ip_network(v['bastion_cidr'],strict=True)
    if parent.version!=4 or not app.subnet_of(parent) or not bastion.subnet_of(parent) or app.overlaps(bastion):
        raise ValueError('Require distinct IPv4 workload/Bastion subnets inside the VNet')
    if bastion.prefixlen>26:raise ValueError('AzureBastionSubnet must be /26 or larger')
    if not re.fullmatch(r'[a-zA-Z][a-zA-Z0-9-]{0,14}',v['computer_name']):raise ValueError('Invalid Windows computer name')
    if 'admin_password' in v:raise ValueError('Do not store administrator passwords in tfvars')
    if type(v['install_iis']) is not bool:raise ValueError('install_iis must be boolean')
    if type(v['os_disk_size_gb']) is not int or not 128<=v['os_disk_size_gb']<=1024:raise ValueError('Invalid disk size')
    return v

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('path');p.add_argument('--live',action='store_true');a=p.parse_args()
    with open(a.path,encoding='utf-8-sig') as f:validate(json.load(f),a.live)
    print('Environment contract passed')
