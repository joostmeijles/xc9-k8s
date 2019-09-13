# Create a cluster
The Azure CLI automates a large part of what is needed to setup a Kubernetes cluster.

To create a resource group and cluster as described [here](https://docs.microsoft.com/en-us//azure/aks/windows-container-cli#create-a-resource-group) run;
```
PS> ./CreateCluster.ps1
```
NB. This automatically create a Service Prinpical: https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/aks/kubernetes-service-principal.md

The script creates a cluster with:
- Linux node (DS2v2, 2 CPUs, 7 GiB RAM, 14 GiB temp storage, €0.1147/hour)
- Windows node (D2sv3, 2 CPUs, 8 GiB RAM, 16 GiB temp storage, €0.1788/hour)
Total costs are approx. €0.30/hour (excluding a small amount of storage costs)

Configure `kubectl` credentials:
```
PS> az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

Connect to the cluster:
```
PS> kubectl get nodes
```
If everything went well you should see 2 nodes.

Browse to the Kubernetes Dashboard to get a visual representation of your cluster:
```
PS> az aks browse --resource-group myResourceGroup --name myAKSCluster
```
[This](https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard) introduces the Kubernetes Dashboard.
> NB. The dashboard allows to deploy services using the Create App option, but does currently not allow for specifying a `nodeSelector`. This means that in a multi-os cluster you cannot specify if the container should be deployed on e.g. a Windows or Linux node.

To save some money during *development*, deallocate the VMs (which are the most costly) in the cluster when you don't use them:
```
PS> ./StopCluster.ps1
```

Start the VMs again using:
```
PS> ./StartCluster.ps1
```

## Setup ACR connection
In order to pull Docker images from an Azure Container Registry you need to grant the cluster Service Principal `AcrPull` rights.

Get Service Principal Id:
```
PS> az aks show --resource-group myResourceGroup --name myAKSCluster --query "servicePrincipalProfile.clientId" --output tsv
```
Use this Id to assign `AcrPull` rights in the ACR. As the ACR lives under a different subscription its easiest do this using the Azure Portal GUI.

See [here](https://docs.microsoft.com/en-us//azure/aks/cluster-container-registry-integration?view=azure-cli-latest) for more details.

## Add Ingress routing
HTTP application routing using AKS is described [here](https://docs.microsoft.com/en-us//azure/aks/http-application-routing). There are several ways of routing ingress traffic, for HTTP traffic there is a choice of Ingress controllers e.g. Nginx, Traefik. As Nginx seems to be the most commonly used and most well documented for AKS we will use Nginx.

### Deploy Nginx Ingress controller
How to deploy a Nginx Ingress controller is described [here](https://kubernetes.github.io/ingress-nginx/deploy/#azure).

It consists of two steps;
1. Mandatory part:
```
PS> kubectl apply -f ./k8s/nginx-ingress.yaml
```
> `nginx-ingress.yaml` is [this](https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml)) + Linux node selector.

1. A cloud provider specific, Azure part:
```
PS> kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/cloud-generic.yaml
```

## Add External DNS configuration
By default you will only have a Ip configured for you cluster. It of course more convenient to have a DNS name assigned to it.
As prerequisite you need to have a domain name and Azure DNS zone setup (see [here](https://docs.microsoft.com/en-us/azure/dns/dns-domain-delegation)). 

To dynamic DNS provisioning for your cluster we use an [external-dns](https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/azure.md) service, to set it up;
- Create a resource group
- Assign `Contributor` rights to AKS Cluster Service Principal
- Create a Kubernetes Secret as described [here](https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/azure.md#creating-configuration-file)
(Get the `aadClientId` and `aadClientSecret` from the automatically created `~/.azure/aksServicePrincipal.json` file)
Creating a Kubernetes secret basically means uploading a JSON file to Kubernetes, e.g:
```
PS> kubectl create secret generic azure-config-file --from-file=azure.json
```

> The filename used to create the secret will by default be used as name when the secret is mounted (`azure.json` in this case)!

Finally deploy the External DNS service:
```
PS> kubectl apply -f .\k8s\externaldns.yaml
```

## Setup Helm
Helm is a package installer for Kubernetes, it makes application installation much easier.

First install Helm on your host machine: 
```
PS> choco install kubernetes-helm
```

To install Helm on AKS:
```
PS> kubectl apply -f ./k8s/helm-rbac.yaml
PS> helm init --service-account tiller --node-selectors "beta.kubernetes.io/os=linux"
```

Read the full details [here](https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm).

## Add automatic TLS certificates
The preferred way is to use cert-manager. It however currently does not fully support `nodeSelector` and thus does not work in hybrid cluster, e.g. like we have with a Linux and Windows node.

The legacy and workaround is to use `kube-lego`:
```
PS> helm install --name kube-lego --set config.LEGO_EMAIL=joost@meijl.es --set config.LEGO_URL=https://acme-v01.api.letsencrypt.org/directory --set nodeSelector."beta\.kubernetes\.io\/os"=linux --set rbac.create=true stable/kube-lego
``` 

Next to enable automatic tls generation for a certain ingress route add an annotation;
```
metadata:
  annotations:
    ...
    kubernetes.io/tls-acme: "true"
```
to your Ingress spec.

Inspect the logs of the `kube-log` to follow the certificaton request process, e.g:
```
PS> kubectl logs kube-lego-kube-lego-7bf7d44dfb-7dnpz
```

# Troubleshooting

## Kubernetes Dashboard errors
Multiple permission errors (as mentioned [here](https://github.com/Azure/aks-engine/issues/805)) show up when browsing the Kubernetes dashboard after performing:
```
PS> az aks browse --resource-group myResourceGroup --name myAKSCluster
```

To fix it, [run](https://github.com/Azure/aks-engine/issues/805#issuecomment-415928684):
```
PS> kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
```

## Resources after removing Kubernetes cluster
After removing a cluster e.g. using:
```
PS> az group delete --name myResourceGroup --yes --no-wait
```

The diagnostics resource group (named `DefaultResourceGroup-WEU` when using the example) is not removed; remove it manually.

## Stop cluster
The VMs inside the cluster cost money. To stop the VMs inside your cluster (i.e. resource group):
```
az vm deallocate --ids $(az vm list -g <RESOURCE GROUP> --query "[].id" -o tsv)
```

To start the VMs again:
```
az vm start --ids $(az vm list -g <RESOURCE GROUP> --query "[].id" -o tsv)
```

## Exec into container
```
PS> kubectl get pods
PS> kubectl exec -ti <pod name> <cmd>
```

## Service types
`Load Balancer` vs `NodePort` vs `ClusterIP`: https://www.edureka.co/community/19351/clusterip-nodeport-loadbalancer-different-from-each-other

## RBAC
Determine if RBAC is enabled for the AKS cluster:
```
az resource show -g <resource group name> -n <cluster name> --resource-type Microsoft.ContainerService/ManagedClusters --query properties.enableRBAC
```
