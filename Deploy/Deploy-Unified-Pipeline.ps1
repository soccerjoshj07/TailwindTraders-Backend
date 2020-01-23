#! /usr/bin/pwsh

Param(
    [parameter(Mandatory=$true)][string]$resourceGroup,
    [parameter(Mandatory=$true)][string]$location,
    [parameter(Mandatory=$false)][string]$clientId,
    [parameter(Mandatory=$false)][string]$password,
    [parameter(Mandatory=$false)][string]$rootFolder,
    [parameter(Mandatory=$false)][bool]$deployAks=$true
)
$gValuesFile="configFile.yaml"

if (!$rootFolder) { $rootFolder = $($MyInvocation.InvocationName | Split-Path) }

Push-Location $rootFolder

# Update the extension to make sure you have the latest version installed
az extension add --name aks-preview 2> $null
az extension update --name aks-preview 2> $null

az account show

Push-Location powershell

# Deploy ARM
& ./Deploy-Arm-Azure.ps1 -resourceGroup $resourceGroup -location $location -clientId $clientId -password $password -deployAks $deployAks

# Connecting kubectl to AKS
Write-Host "Retrieving Aks Name" -ForegroundColor Yellow
$aksName = $(az aks list -g $resourceGroup -o json | ConvertFrom-Json).name
Write-Host "The name of your AKS: $aksName" -ForegroundColor Yellow

# Write-Host "Retrieving credentials" -ForegroundColor Yellow
az aks get-credentials -n $aksName -g $resourceGroup

# Generate Config
$gValuesLocation=$(./Join-Path-Recursively.ps1 -pathParts ..,helm,__values,$gValuesFile)
& ./Generate-Config.ps1 -resourceGroup $resourceGroup -outputFile $gValuesLocation

# Create Secrets
$acrName = $(az acr list --resource-group $resourceGroup --subscription $subscription -o json | ConvertFrom-Json).name
Write-Host "The Name of your ACR: $acrName" -ForegroundColor Yellow
& ./Create-Secret.ps1 -resourceGroup $resourceGroup -acrName $acrName

# Build an Push
& ./Build-Push.ps1 -resourceGroup $resourceGroup -acrName $acrName -isWindows $false

# Deploy images in AKS
$gValuesLocation=$(./Join-Path-Recursively.ps1 -pathParts __values,$gValuesFile)
& ./Deploy-Images-Aks.ps1 -aksName $aksName -resourceGroup $resourceGroup -charts "*" -acrName $acrName -valuesFile $gValuesLocation

# Deploy pictures in AKS
$storageName = $(az resource list --resource-group $resourceGroup --resource-type Microsoft.Storage/storageAccounts -o json | ConvertFrom-Json).name
& ./Deploy-Pictures-Azure.ps1 -resourceGroup $resourceGroup -storageName $storageName

Pop-Location
Pop-Location