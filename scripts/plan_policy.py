"""Offline plan gate. Do not emit plan values or secrets into logs."""
import argparse,json

def inspect(plan):
    if plan.get('complete') is not True or plan.get('errored') or plan.get('deferred_changes'):
        raise ValueError('Require a complete, successful plan without deferred changes')
    count=0
    for row in plan.get('resource_changes',[]):
        if row.get('mode')=='data':continue
        actions=row['change']['actions']
        if actions not in (['no-op'],['create'],['update']):
            raise ValueError('Destructive or unsupported action: '+row['address'])
        if actions!=['no-op']:count+=1
    return count

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('path');a=p.parse_args()
    with open(a.path,encoding='utf-8-sig') as f:plan=json.load(f)
    print('Plan policy passed; managed changes:',inspect(plan))
