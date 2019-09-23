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

We use Azure Disk for our SQL and Solr databases and a Kubernetes Secret for the Sitecore license file.

### Sitecore license
Create a Kubernetes secret from your `license.xml` file:
```
PS> kubectl create secret generic sitecore-license --from-file=license.xml
```

Verify that it present:
```
PS> kubectl describe secrets sitecore-license
```

This will create a storage (named `license`) and secret (named `azure-licenseshare-secret`) that can be used in a Kubernetes YAML file as follows:
```
    container:
      ...
      volumeMounts:
          - mountPath: "/license"
            name: license
            readOnly: true
    ...
    volumes:
        - name: license
          secrete:
            secretName: sitecore-license
```

## Configure external HTTPS, internal  HTTP
In order to dynamically assign domain names and sign certificates its easiest to let the Ingress controller handle HTTPS and internally use HTTP. As the cluster internal network is private using HTTP is okay.

To remove an existing HTTPS binding and replace it by a HTTP binding, you can use the following Powershell commands:
```
Get-WebBinding -Name $bindingName -Protocol 'https' -Port 443 | Remove-WebBinding
New-WebBinding -Name $bindingName -HostHeader '*' -IPAddress * -Protocol 'http' -Port 80
```

This change is necessary for the Commerce Business tools, Identity server.

## Enable reverse proxy support 
Identity Server 9.1 does not have reverse-proxy support out-of-the-box. To enable reverse proxy support add [this]( https://github.com/joostmeijles/Sitecore.Identity.ProxySupport) plugin. 

## Update CORS config
Update all CORS allowed origins:
- for the Identity Server (e.g. all files in directory `C:\inetpub\wwwroot\identity\Config\production`)
- In the Commerce container modify all configs that are changed by the `UpdateHostname.ps1` script at start-up

## Update Sitecore config
Update Commerce engine URLs in `Y.Commerce.Engine\Sitecore.Commerce.Engine.Connect.config`

# Run application
Once all Kubernetes YAML spec files are prepared, it is simply a matter of applying all these:
```
PS> kubectl apply -f ./xc9
```
and wait for the Pods to be running. 

Inspect the Pod states by performing:
```
PS> kubectl get pods -o wide
```

## Connect to containers in cluster
For troubleshooting exec-ing into a Pod is very useful. To open a powershell in a Pod:
```
PS> kubectl exec -ti <pod> powershell
```

If necessary there are options to use [SSH](https://docs.microsoft.com/en-us/azure/aks/ssh) and [RDP](https://docs.microsoft.com/en-us/azure/aks/rdp) to inspect a Pod.
