Param(
    [string]$StorageAccountName = (Get-Random -Maximum 99999999 | % {"mystorageaccount$_"}),
    [string]$ResourceGroup = "myAKSShare",
    [string]$Location = "westeurope",
    [string]$ShareName = "license",
    [string]$SecretName = "azure-licenseshare-secret"
)

# Create a resource group
az group create --name $ResourceGroup --location $Location

# Create a storage account
az storage account create -n $StorageAccountName -g $ResourceGroup -l $Location --sku Standard_LRS

# Export the connection string as an environment variable, this is used when creating the Azure file share
$StorageConnectionString=(az storage account show-connection-string -n $StorageAccountName -g $ResourceGroup -o tsv)

# Create the file share
az storage share create -n $ShareName --connection-string $StorageConnectionString --quota 1

# Get storage account key
$StorageKey=(az storage account keys list --resource-group $ResourceGroup --account-name $StorageAccountName --query "[0].value" -o tsv)

# Echo storage account name and key
Write-Output "Storage account name: $StorageAccountName"
Write-Output "Storage account key: $StorageKey"

# Create Kubernetes secret
kubectl create secret generic $SecretName --from-literal=azurestorageaccountname="$StorageAccountName" --from-literal=azurestorageaccountkey="$StorageKey"
