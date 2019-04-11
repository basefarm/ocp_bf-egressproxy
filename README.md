# bf-squid

## Setup build and push image

### Install and setup packages

Install git, docker:

```
yum install -y git docker
lvextend -r /dev/vg0/Var -L 15GB
systemctl enable docker
systemctl start docker
```

### Trust

If no key exist create one (no password), and copy the public key to the buffer. 

```
ssh-keygen -t rsa -b 4096 -C "openshift-team@basefarm.com"
```

Then create a deploy key on the repo in GitHub using that buffer. 


### Proxy

If you require a proxy.

#### Docker

Add to /etc/sysconfig/docker :

```
HTTP_PROXY=http://bf-proxy.osl.basefarm.net:8888
HTTPS_PROXY=http://bf-proxy.osl.basefarm.net:8888
NO_PROXY="*.basefarm.net, 10.0.0.0/8"
```


#### subscription-manager

```
subscription-manager config --server.proxy_hostname=bf-proxy.osl.basefarm.net --server.proxy_port=8888
```

#### yum

Add to /etc/yum.conf 's [main]:

```
proxy=http://bf-proxy.osl.basefarm.net:8888
```


### Upstream

As we don't have RHNS6, we have to do this hack. 

From any machine with ocp (as pwrepo slot matches on *ocp*):

```
dam-pwrepo get https://pwrepo.basefarm.com/configuration/content/access.redhat.com/bf-sa-ocp
```

Copy paste result to the shell.


Then: 

```
subscription-manager register --username "$username" --password "$password"
subscription-manager config --rhsm.auto_enable_yum_plugins=0
subscription-manager attach --pool=8a85f9815dc622e3015dc66dc0751537
subscription-manager repos --disable=rhel-7-server-rpms
```


### Build

Remove if running: 

`docker rm -fv bf-squid`

Build, run, check log and execute a cmd: 

```
mkdir -p /root/repositories
cd /root/repositories
git clone git@github.com:basefarm/ocp_bf-squid.git
cd /root/repositories/ocp_bf-squid
docker build . -t bf/bf-squid:latest
docker run -d -it -p 3128:3128 --name=bf-squid bf/bf-squid
docker logs bf-squid
docker exec -it bf-squid pwd
```

You can test the proxy by setting the export, remove proxy with unset: 

```
export http_proxy=http://127.0.0.1:3128 https_proxy=http://127.0.0.1:3128
unset http_proxy https_proxy
```

Make sure there is a public-repo project/repo, that your user has access to push to public-repo repo/project, and anonymous has access to pull: 

```
oc new-project public-repo
oc policy add-role-to-user registry-editor USER -n public-repo
oc policy add-role-to-user registry-viewer system:anonymous -n public-repo
```

Login to OCP as your own user, get token:

```
oc whoami -t
```

Then login to docker: 

```
server=bf-ocps1-registry.p2.osl.basefarm.net:443
docker login ${server}
```

Then tag and push, to the public-repo repository: 

```
docker tag bf/bf-squid ${server}/public-repo/bf-squid:testing
docker push ${server}/public-repo/bf-squid:testing
```

This will upload the image as :testing , usually you want to upload it as it's version (from Dockerfile). When happy, tag it as :testing for a last stage before prod, **when ready for production tag as :latest.**


## Implement on customer environment

You need access to BF-s GitHub in order to complete these steps. 

These resources will probably be migrated to a public space so it's easier to implement. But for now just your personal "Personal access token". 


### Download templates

root@master1: 

```
mkdir -p /root/repositories
cd /root/repositories
git clone https://github.com/basefarm/ocp_bf-squid.git
cd /root/repositories/ocp_bf-squid
```


### Get access to public-repo

Our shared docker registry is hosted on the bf-ocps1 environment, it's VIP is already exposed to 10.0.0.0/8. If you require other expsures contact OpenShift Team. 

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
    creationTimestamp: null
    name: default
  spec:
    egress:
    - to:
        cidrSelector: 0.0.0.0/0
      type: Allow
kind: List
metadata: {}" | oc apply -n $project -f -
oc annotate ns --overwrite $project openshift.io/node-selector='node-role.kubernetes.io/infra=true'
```

### Create egressproxy service

```
oc process -f openshift/egressproxy-template.yaml | oc create -f -
```

### Setup RBAC

This is CT domain, but a suggestion is to allow the customer access to the project, and allow access to modify the ConfigMaps. 

Normally changing a ConfigMap will "do nothing", as the ConfigMap is mounted as a volume in the container, and changing the CM won't trigger a new rollout. But this is logic is put into the container itself, so it works with bf-squid and egressproxy!!!
