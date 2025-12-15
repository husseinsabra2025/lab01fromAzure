# Quick Start Commands - Your Configuration

## Your Azure Resources
- **Resource Group**: sword-devops-01-rg
- **Subscription ID**: 20d12d83-267a-4879-842e-117791537e50
- **Region**: eastus
- **ACR Name**: demoacrsword0101
- **AKS Cluster**: aksdemoswordcluster
- **App Insights**: demoacrsword0101

---

## Step 1: Login to Azure

```powershell
# Login to Azure
az login

# Set the correct subscription
az account set --subscription "20d12d83-267a-4879-842e-117791537e50"

# Verify subscription
az account show
```

---

## Step 2: Navigate to Project Directory

```powershell
cd c:\DevOps-training\Proj-1\aks-devops-project
```

---

## Step 3: Run Azure Resources Setup Script

```powershell
.\scripts\setup-azure-resources.ps1 `
    -ResourceGroupName "sword-devops-01-rg" `
    -Location "eastus" `
    -AcrName "demoacrsword0101" `
    -AksName "aksdemoswordcluster" `
    -AppInsightsName "demoacrsword0101"
```

**⏱️ This will take 5-10 minutes**

**🔑 IMPORTANT**: Copy the Application Insights Connection String from the output!

---

## Step 4: Update Secret File

After the script completes, update the secret file:

1. Open: `c:\DevOps-training\Proj-1\aks-devops-project\k8s\secret.yaml`
2. Replace `YOUR_APP_INSIGHTS_CONNECTION_STRING_HERE` with the connection string from the setup script output

---

## Step 5: Test Docker Build (Optional)

```powershell
# Navigate to src directory
cd c:\DevOps-training\Proj-1\aks-devops-project\aks-devops-project\src

# Build Docker image
docker build -t aks-demo-api:local -f Dockerfile .

# Run container
docker run -d -p 8080:80 --name aks-test aks-demo-api:local

# Test endpoints
Start-Sleep -Seconds 5
curl http://localhost:8080
curl http://localhost:8080/api/health
curl http://localhost:8080/api/products

# Cleanup
docker stop aks-test
docker rm aks-test

# Go back to project root
cd c:\DevOps-training\Proj-1
```

---

## Step 6: Push Code to Azure DevOps

```powershell
# Ensure you're in project root
cd c:\DevOps-training\Proj-1

# Add all files
git add .

# Commit changes
git commit -m "Add AKS deployment lab with configuration"

# Push to Azure DevOps
git push origin main
```

---

## Step 7: Create Azure DevOps Service Connection

1. Go to your Azure DevOps project
2. **Project Settings** → **Service connections**
3. **New service connection** → **Azure Resource Manager**
4. **Service principal (automatic)**
5. Configure:
   - **Subscription**: Select subscription (20d12d83-267a-4879-842e-117791537e50)
   - **Resource group**: sword-devops-01-rg
   - **Service connection name**: azure-aks-sword-connection
   - ✅ Check "Grant access permission to all pipelines"
6. **Save**

---

## Step 8: Update Pipeline with Service Connection Name

After creating the service connection, update `azure-pipelines.yml`:

Replace:
```yaml
azureSubscription: 'YOUR_SERVICE_CONNECTION_NAME'
```

With:
```yaml
azureSubscription: 'azure-aks-sword-connection'
```

Also update the App Insights connection string from the setup script output.

Then commit and push:
```powershell
git add azure-pipelines.yml
git commit -m "Update pipeline with service connection"
git push origin main
```

---

## Step 9: Create and Run Pipeline

1. **Pipelines** → **New pipeline**
2. **Azure Repos Git** → Select your repository
3. **Existing Azure Pipelines YAML file**
4. Select `/azure-pipelines.yml`
5. **Run**

---

## Step 10: Monitor Deployment

```powershell
# Get AKS credentials
az aks get-credentials --resource-group sword-devops-01-rg --name aksdemoswordcluster --overwrite-existing

# Watch pods
kubectl get pods -n aks-demo -w

# In another terminal, watch service
kubectl get svc -n aks-demo -w
```

---

## Step 11: Get Application URL

```powershell
# Get external IP
$EXTERNAL_IP = kubectl get svc aks-demo-api-service -n aks-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "🎉 Application URL: http://$EXTERNAL_IP" -ForegroundColor Green
Write-Host "Health Check: http://$EXTERNAL_IP/api/health" -ForegroundColor Cyan
Write-Host "Products API: http://$EXTERNAL_IP/api/products" -ForegroundColor Cyan

# Test endpoints
curl "http://$EXTERNAL_IP"
curl "http://$EXTERNAL_IP/api/health"
curl "http://$EXTERNAL_IP/api/products"
```

---

## Useful Commands

### View Resources
```powershell
# View all Kubernetes resources
kubectl get all -n aks-demo

# View pod details
kubectl describe pod -n aks-demo -l app=aks-demo-api

# View logs
kubectl logs -n aks-demo -l app=aks-demo-api --tail=50

# View events
kubectl get events -n aks-demo --sort-by='.lastTimestamp'
```

### Scale Application
```powershell
# Scale to 5 replicas
kubectl scale deployment aks-demo-api -n aks-demo --replicas=5

# Scale back to 3
kubectl scale deployment aks-demo-api -n aks-demo --replicas=3
```

### View Azure Resources
```powershell
# List resources in resource group
az resource list --resource-group sword-devops-01-rg -o table

# Get ACR details
az acr show --name demoacrsword0101 --resource-group sword-devops-01-rg

# Get AKS details
az aks show --name aksdemoswordcluster --resource-group sword-devops-01-rg

# View AKS nodes
az aks show --name aksdemoswordcluster --resource-group sword-devops-01-rg --query agentPoolProfiles
```

---

## Troubleshooting

### If pods are not starting:
```powershell
kubectl describe pod -n aks-demo -l app=aks-demo-api
kubectl logs -n aks-demo -l app=aks-demo-api --tail=100
```

### If can't pull from ACR:
```powershell
az aks check-acr --resource-group sword-devops-01-rg --name aksdemoswordcluster --acr demoacrsword0101.azurecr.io
```

### If service has no external IP:
```powershell
kubectl describe svc aks-demo-api-service -n aks-demo
```

---

## Cleanup

```powershell
# Delete Kubernetes namespace
kubectl delete namespace aks-demo

# Delete Azure resources (WARNING: Deletes everything in the RG)
az group delete --name sword-devops-01-rg --yes --no-wait
```

---

## Files Already Updated

✅ **azure-pipelines.yml** - Updated with your resource names
✅ **k8s/deployment.yaml** - Updated with your ACR name (demoacrsword0101.azurecr.io)

**Still need to update manually:**
⚠️ **k8s/secret.yaml** - Update with App Insights connection string after running setup script
⚠️ **azure-pipelines.yml** - Update `azureSubscription` after creating service connection
⚠️ **azure-pipelines.yml** - Update `appInsightsConnectionString` after running setup script
