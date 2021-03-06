Param(
    [string]$ResourceGroup = "myResourceGroup",
    [string]$ClusterName = "myAKSCluster",
    [string]$Location = "westeurope"
)

$vmssResourceGroup="MC_${ResourceGroup}_${ClusterName}_${Location}"

# List all VM scale sets
$vmssNames=(az vmss list --resource-group $vmssResourceGroup --query "[].id" -o tsv | Split-Path -Leaf)

# Deallocate first instance for each VM scale set
$vmssNames | ForEach-Object { az vmss deallocate --resource-group $vmssResourceGroup --name $_  --instance-ids 0}
