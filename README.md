# bf-egressproxy

## Implement on customer environment

### Download templates

root@master1: 

```
mkdir -p /root/repositories
cd /root/repositories
git clone https://github.com/basefarm/ocp_bf-egressproxy.git
cd /root/repositories/ocp_bf-egressproxy
```


### Get access to public-repo

Our shared docker registry is hosted on the bf-ocps1 environment, it's VIP is already exposed to 10.0.0.0/8. If you require other exposures contact OpenShift Team. 

Make sure your environment has outgoing access to the VIP. This is usually in place by default, through the Primo "any-tcp" external service. 


### Create shared imagestream

So all projects can access the image. 

root@master1: 

```
server=bf-ocps1-registry.p2.osl.basefarm.net:443
oc process DOCKER_IMAGE_URL=${server} -f openshift/bf-squid-is-template.yaml | oc create -n openshift -f -
```

### Create egressproxy project

Create project, make "global", allow all outgoing connections, set node-selector to infra: 

```
project=egressproxy
oc new-project $project
oc adm pod-network make-projects-global $project
echo "apiVersion: v1
items:
- apiVersion: v1
  kind: EgressNetworkPolicy
  metadata:
    annotations:
      openshift.io/node-selector: node-role.kubernetes.io/infra=true
    creationTimestamp: null
    name: default
  spec:
    egress:
    - to:
        cidrSelector: 0.0.0.0/0
      type: Allow
kind: List
metadata: {}" | oc apply -n $project -f -
```

### Create egressproxy service

You can set ID to whatever you like. The ID will be part of the names like this: 

- Service: egressproxy-${ID}
- ConfigMap: egressproxy-${ID}a-allow-policy
- DeploymentConfig: egressproxy-${ID}a
- ConfigMap: egressproxy-${ID}b-allow-policy
- DeploymentConfig: egressproxy-${ID}b

```
oc process ID=1 -f openshift/egressproxy-template.yaml | oc create -f -
```

### Setup RBAC

This is CT domain, but a suggestion is to allow the customer access to the project, and allow access to modify the ConfigMaps labeled. See `oc create role -h` and `oc create clusterrole -h`. 

Normally changing a ConfigMap will "do nothing", as the ConfigMap is mounted as a volume in the container, and changing the CM won't trigger a new rollout. But this is logic is put into the container itself, so it works with bf-squid and bf-egressproxy!!!
