#! /usr/bin/pwsh

Param (
    [parameter(Mandatory=$true)][string]$resourceGroup,
    [parameter(Mandatory=$false)][string]$aksName
)

if ([string]::IsNullOrEmpty($aksName)) {
    Write-Host "No AKS name. Quering resourceGroup $resourceGroup to calculate name" -ForegroundColor Yellow
    $aksName = $(az aks list -g $resourceGroup -o json | ConvertFrom-Json).name
    Write-Host "AKS Name = $aksName"
}

Write-Host "Getting k8s cluster credentials"
az aks get-credentials -g $resourceGroup -n $aksName

Write-Host "--------------------------------------------------------" -ForegroundColor Yellow
Write-Host " Enabling Cert Manager on cluster $aksName in RG $resourceGroup"  -ForegroundColor Yellow
Write-Host " --------------------------------------------------------" -ForegroundColor Yellow
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo add jetstack https://charts.jetstack.io
helm repo update

kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.13/deploy/manifests/00-crds.yaml

# Install the cert-manager Helm chart
helm upgrade --install cert-manager jetstack/cert-manager --version v0.13.0