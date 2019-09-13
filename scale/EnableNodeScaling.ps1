Param(
    [string]$ResourceGroup = "myCluster",
    [string]$ClusterName = "myAKSCluster",
    [string]$MinNodes = "1",
    [string]$MaxNodes = "3"
)

az aks update `
  --resource-group $ResourceGroup `
  --name $ClusterName `
  --update-cluster-autoscaler `
  --min-count $MinNodes `
  --max-count $MaxNodes
