# Azure Resources Setup Script
# This script creates ACR, AKS, and Application Insights

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [string]$AcrName,
    
    [Parameter(Mandatory=$true)]
    [string]$AksName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppInsightsName
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Azure Resources Setup for AKS Lab" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "Location: $Location" -ForegroundColor White
Write-Host "ACR Name: $AcrName" -ForegroundColor White
Write-Host "AKS Name: $AksName" -ForegroundColor White
Write-Host "App Insights: $AppInsightsName" -ForegroundColor White
Write-Host ""

# Check if logged in to Azure
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
$account = az account show 2>$null
if (-not $account) {
    Write-Host "Not logged in. Logging in to Azure..." -ForegroundColor Yellow
    az login
}

$currentSub = az account show --query name -o tsv
Write-Host "Logged in to subscription: $currentSub" -ForegroundColor Green
Write-Host ""

# Check if resource group exists
Write-Host "[Step 1/5] Checking Resource Group..." -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    Write-Host "Creating Resource Group: $ResourceGroupName" -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location
    Write-Host "Resource Group created" -ForegroundColor Green
} else {
    Write-Host "Resource Group already exists" -ForegroundColor Green
}
Write-Host ""

# Create Azure Container Registry
Write-Host "[Step 2/5] Creating Azure Container Registry..." -ForegroundColor Yellow
$acrExists = az acr show --name $AcrName --resource-group $ResourceGroupName 2>$null
if (-not $acrExists) {
    az acr create `
        --resource-group $ResourceGroupName `
        --name $AcrName `
        --sku Basic `
        --location $Location `
        --admin-enabled true
    Write-Host "ACR created successfully" -ForegroundColor Green
} else {
    Write-Host "ACR already exists" -ForegroundColor Green
}

$acrLoginServer = az acr show --name $AcrName --query loginServer -o tsv
Write-Host "  Login Server: $acrLoginServer" -ForegroundColor Cyan
Write-Host ""

# Create Log Analytics Workspace
Write-Host "[Step 3/5] Creating Log Analytics Workspace..." -ForegroundColor Yellow
$workspaceName = "$AksName-logs"
$workspaceExists = az monitor log-analytics workspace show `
    --resource-group $ResourceGroupName `
    --workspace-name $workspaceName 2>$null

if (-not $workspaceExists) {
    az monitor log-analytics workspace create `
        --resource-group $ResourceGroupName `
        --workspace-name $workspaceName `
        --location $Location
    Write-Host "Log Analytics Workspace created" -ForegroundColor Green
} else {
    Write-Host "Log Analytics Workspace already exists" -ForegroundColor Green
}

$workspaceId = az monitor log-analytics workspace show `
    --resource-group $ResourceGroupName `
    --workspace-name $workspaceName `
    --query id -o tsv
Write-Host ""

# Create Application Insights
Write-Host "[Step 4/5] Creating Application Insights..." -ForegroundColor Yellow
$appInsightsExists = az monitor app-insights component show `
    --app $AppInsightsName `
    --resource-group $ResourceGroupName 2>$null

if (-not $appInsightsExists) {
    az monitor app-insights component create `
        --app $AppInsightsName `
        --location $Location `
        --resource-group $ResourceGroupName `
        --workspace $workspaceId `
        --application-type web
    Write-Host "Application Insights created" -ForegroundColor Green
} else {
    Write-Host "Application Insights already exists" -ForegroundColor Green
}

$appInsightsKey = az monitor app-insights component show `
    --app $AppInsightsName `
    --resource-group $ResourceGroupName `
    --query instrumentationKey -o tsv

$appInsightsConnectionString = az monitor app-insights component show `
    --app $AppInsightsName `
    --resource-group $ResourceGroupName `
    --query connectionString -o tsv
Write-Host ""

# Create AKS Cluster
Write-Host "[Step 5/5] Creating AKS Cluster (This will take 5-10 minutes)..." -ForegroundColor Yellow
$aksExists = az aks show --name $AksName --resource-group $ResourceGroupName 2>$null

if (-not $aksExists) {
    az aks create `
        --resource-group $ResourceGroupName `
        --name $AksName `
        --location $Location `
        --node-count 2 `
        --node-vm-size Standard_B2s `
        --enable-managed-identity `
        --attach-acr $AcrName `
        --enable-addons monitoring `
        --workspace-resource-id $workspaceId `
        --generate-ssh-keys `
        --network-plugin azure `
        --network-policy azure
    Write-Host "AKS Cluster created successfully" -ForegroundColor Green
} else {
    Write-Host "AKS Cluster already exists" -ForegroundColor Green
    Write-Host "Ensuring ACR integration..." -ForegroundColor Yellow
    az aks update --name $AksName --resource-group $ResourceGroupName --attach-acr $AcrName
    Write-Host "ACR integration verified" -ForegroundColor Green
}
Write-Host ""

# Get AKS Credentials
Write-Host "Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials `
    --resource-group $ResourceGroupName `
    --name $AksName `
    --overwrite-existing
Write-Host "Credentials configured for kubectl" -ForegroundColor Green
Write-Host ""

# Test kubectl connection
Write-Host "Testing kubectl connection..." -ForegroundColor Yellow
kubectl get nodes
Write-Host ""

# Display Summary
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Summary:" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray
Write-Host "Resource Group    : $ResourceGroupName" -ForegroundColor White
Write-Host "Location          : $Location" -ForegroundColor White
Write-Host "ACR Name          : $AcrName" -ForegroundColor White
Write-Host "ACR Login Server  : $acrLoginServer" -ForegroundColor White
Write-Host "AKS Cluster       : $AksName" -ForegroundColor White
Write-Host "App Insights      : $AppInsightsName" -ForegroundColor White
Write-Host ""
Write-Host "Important Information:" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray
Write-Host "Application Insights Connection String:" -ForegroundColor Cyan
Write-Host $appInsightsConnectionString -ForegroundColor White
Write-Host ""
Write-Host "SAVE THIS CONNECTION STRING!" -ForegroundColor Red -BackgroundColor Yellow
Write-Host "   You'll need it for:" -ForegroundColor Yellow
Write-Host "   1. Updating k8s/secret.yaml" -ForegroundColor White
Write-Host "   2. Azure DevOps pipeline variables" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "-------------------------------------------" -ForegroundColor Gray
Write-Host "1. Update k8s/secret.yaml with the App Insights connection string" -ForegroundColor White
Write-Host "2. Update k8s/deployment.yaml with ACR name: $acrLoginServer" -ForegroundColor White
Write-Host "3. Test Docker build locally (optional)" -ForegroundColor White
Write-Host "4. Push code to Azure DevOps" -ForegroundColor White
Write-Host "5. Create Azure DevOps pipeline" -ForegroundColor White
Write-Host ""
