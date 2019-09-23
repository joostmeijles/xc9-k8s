As use-case we will use the Mercury Demo website. Mercury is a Sitecore Commerce accelerator (https://mercury-ecommerce.com/) and there is a Dockerized demonstration environment available (on request from https://github.com/avivasolutionsnl/mercury-demo).
Having a fully Dockerized webshop allows us to quickly get up and running in Kubernetes.

Start the Mercury demo in Kubernetes using:
```
PS> kubectl apply -f ./scale
```
> Remove the `xc9` deployment before running this example

# Scale application
To perform scaling you need to make the number of *nodes* and *pods* variable.

To enable Node scaling (full details [here](https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler)), add the `--enable-cluster-autoscaler` and minimum and maximum number of nodes to your cluster create or update command, e.g:
```
--enable-cluster-autoscaler --min-count 1 --max-count 5
```
> The cluster autoscaler has many more parameters, see [here](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-the-parameters-to-ca)
Run `EnableNodeScaling.ps1` to add auto-scaling to a running cluster.

To enable Pod scaling (full details [here](https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-scale)), specify resources for the containers in your Pod, e.g:
```
resources:
  requests:
     cpu: 250m
  limits:
     cpu: 500m
```

That's all, your cluster nodes and pods will scale horizontally based on the measured load.

# Trigger load
```
PS> docker run -i loadimpact/k6 run -u 100 -d 30s -< loadtest.js
```

```
PS> kubectl autoscale deployment commerce-deployment --cpu-percent=10 --min=1 --max=10
```


https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/
https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/