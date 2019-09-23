As use-case we will use the Mercury Demo website. Mercury is a Sitecore Commerce accelerator (https://mercury-ecommerce.com/) and there is a Dockerized demonstration environment available (on request from https://github.com/avivasolutionsnl/mercury-demo).
Having a fully Dockerized webshop allows us to quickly get up and running in Kubernetes.

Start the Mercury demo in Kubernetes using:
```
PS> kubectl apply -f ./scale
```
> Remove the `xc9` deployment before running this example

# Scale application
You can scale cluster nodes and pods.

To enable Node scaling (full details [here](https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler)), add the `--enable-cluster-autoscaler` and minimum and maximum number of nodes to your cluster create or update command, e.g:
```
--enable-cluster-autoscaler --min-count 1 --max-count 5
```
> The cluster autoscaler has many more parameters, see [here](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-the-parameters-to-ca)
Run `EnableNodeScaling.ps1` to add auto-scaling to a running cluster.

To enable Pod scaling (full details [here](https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-scale)), specify resources *per* container in a Pod, e.g:
```
resources:
  requests: # Minimum
     cpu: 250m
  limits: # Maximum
     cpu: 250m
```
Above states that the container requests at least *and* at most 250 milli CPU (i.e. 25% CPU).

Next add a `HorizontalPodAutoscaler`, for example:

```
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: commerce
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: commerce
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50 # Target is 50% of the requested CPU accros all pods, i.e. 50% of 250 milli CPU in this case
```
Above spec requests to add a Pod when a the CPU load for a single Pod, which is the minimum and initial situation, goes above 50% of the requested 250 milli CPU.

See [here](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) for full details.

# Trigger load
To trigger some load we will use K6 Loadimpact.

In `loadtest.js` a single product is added to the cart. 

To run this cart addition for 30 seconds and 100 virtual users do:
```
PS> docker run -i loadimpact/k6 run -u 100 -d 30s -< loadtest.js
```

Monitor the number of Pod replicas by:
```
PS> kubectl get pod -w
```
