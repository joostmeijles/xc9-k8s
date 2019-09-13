Param(
    [string]$ResourceGroup = "myResourceGroup",
    [string]$Location = "westeurope",
    [string]$ClusterName = "myAKSCluster",
    [string]$WindowsAdminUser = "azureuser",
    [string]$WindowsPassword = "P@ssw0rd1234"
)

# Create a resource group
az group create --name $ResourceGroup --location $Location

# Create a Kubernetes cluster
# This creates a Linux node, Windows credentials are used for Windows containers to run on the cluster
az aks create --resource-group $ResourceGroup `
    --name $ClusterName `
    --node-count 1 `
    --enable-addons monitoring `
    --kubernetes-version 1.14.5 `
    --generate-ssh-keys `
    --windows-admin-password $WindowsPassword `
    --windows-admin-username $WindowsAdminUser `
    --enable-vmss `
    --network-plugin azure

# Add a Windows Server node to the cluster
az aks nodepool add --resource-group $ResourceGroup `
    --cluster-name $ClusterName `
    --os-type Windows `
    --name npwin `
    --node-count 1 `
    --kubernetes-version 1.14.5
