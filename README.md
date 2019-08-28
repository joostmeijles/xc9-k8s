# XC9 + K8S + AKS = Bingo!
This repository investigates the possibilities of using Azure Kubernetes Service (AKS) for running Sitecore eXperience Commerce 9 (XC9).

Kubernetes (K8S) introduces, on top of Docker, a number of new concepts: https://kubernetes.io/docs/concepts/

Running Windows containers on AKS is currently in preview. Microsoft offers guide to get an example Windows application running: Follow https://docs.microsoft.com/en-us/azure/aks/windows-container-cli 

Not that you can currently not run Kubernetes & Windows containers locally as Docker Desktop has only Kubernetes support for Linux containers (hopefully this will change in the future with the official release of WSL 2).

> DISCLAIMER
> This repository provides a Sitecore XC 9 AKS setup for *study* purposes and is not to be meant to be used in production.

# Create a cluster
The Azure CLI automates large part of what is needed to setup a Kubernetes cluster.

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
PS> az aks get-credentials --resource-group myCluster --name myAKSCluster
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

### Setup ACR connection
In order to pull Docker images from an Azure Container Registry you need to grant the cluster Service Principal `AcrPull` rights.

Get Service Principal Id:
```
PS> az aks show --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "servicePrincipalProfile.clientId" --output tsv
```
Use this Id to assign `AcrPull` rights in the ACR. As the ACR lives under a different subscription its easiest do this using the Azure Portal GUI.

See [here](https://docs.microsoft.com/en-us//azure/aks/cluster-container-registry-integration?view=azure-cli-latest) for more details.

# Prepare application
The Docker Compose setup needs to be translated into a Kubernetes setup. 
Where Docker Compose uses mostly one YAML config file (see [here](./docker-compose.yml)), our Kubernetes setup will have about one file per Deployment / Service.

The Kubernetes config files can be found [here](./k8s)

NB. You could use [Kompose](http://kompose.io/) to convert a docker-compose.yml to a Kubernetes YAML file. 
> Use a major version in your docker-compose.yml, e.g. replace `2.4` by `2` (see conversion matrix [here](http://kompose.io/conversion/))

## Add storage
There are two options for file storage in AKS:
- [Azure Disk](https://docs.microsoft.com/en-us//azure/aks/azure-disks-dynamic-pv)
- [Azure Files](https://docs.microsoft.com/en-us//azure/aks/azure-files-dynamic-pv)

We use Azure Disk for our SQL and Solr databases and Azure Files for mounting the Sitecore license file.
> TODO: Investigate lifetime

To create an Azure Files share for the Sitecore license file, run:
```
PS> ./CreateLicenseStorage.ps1
```

This will create a storage (named `license`) and secret (named `azure-licenseshare-secret`) that can be used in a Kubernetes YAML file as follows:
```
    ...
    volumes:
        - name: license
          azureFile:
            secretName: azure-licenseshare-secret
            shareName: license
            readOnly: true
```

Copy the actual license file to the share by using the Azure Portal or SMB mount.

# Ingress routing
HTTP application routing using AKS is described [here](https://docs.microsoft.com/en-us//azure/aks/http-application-routing). There are several ways of routing ingress traffic, for HTTP traffic there is a choice of Ingress controllers e.g. Nginx, Traefik. As Nginx seems to be the most commonly used and most well documented for AKS we chose this one.

## Deploy Nginx Ingress controller
How to deploy a Nginx Ingress controller is described [here](https://kubernetes.github.io/ingress-nginx/deploy/#azure).

It consists of two steps;
1. Mandatory part:
```
PS> kubectl apply -f ./k8s/nginx-ingress.yml
```
> `nginx-ingress.yml` is [this](https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml)) + Linux node selector.

1. A cloud provider specific, Azure part:
```
PS> kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/cloud-generic.yaml
```

## External HTTPS, internal  HTTP
In order to dynamically assign domain names and sign certificates its easiest to let the Ingress controller handle HTTPS and internally use HTTP. As the cluster internal network is private using HTTP is okay.

To remove an existing HTTPS binding and replace it by a HTTP binding, you can use the following Powershell commands:
```
Get-WebBinding -Name $bindingName -Protocol 'https' -Port $port | Remove-WebBinding
New-WebBinding -Name $bindingName -HostHeader '*' -IPAddress * -Protocol 'http' -Port $port
```

This change is necessary for the Commerce Business tools, Identity server.

# External DNS configuration
https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/azure.md
- Create resource group
- Assign `Contributor` rights to AKS Cluster Service Principal
- Create Kubernetes Secret: https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/azure.md#creating-configuration-file
(Get the `aadClientId` and `aadClientSecret` from the automatically created `~/.azure/aksServicePrincipal.json` file)
--> This basically uploads the JSON file as secret to Kubernetes
NB. The file that's used to create the secret will by default be used when the secret is mounted (`azure.json` in this case)!

# Run application

> TODO
> Scaling, updating, upgrading nodes in cluster
> Helm

## Connect to containers in cluster
```
PS> kubectl exec -ti <pod> powershell
```
https://docs.microsoft.com/en-us/azure/aks/ssh -> Create a helper SSH Pod
https://docs.microsoft.com/en-us/azure/aks/rdp -> Create a VM on the same subnet as cluster VM and RDP into it.


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