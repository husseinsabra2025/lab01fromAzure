# 🚀 AKS Deployment Guide v2.0 - Complete Walkthrough

**Updated:** December 2025  
**Lab:** Deploy AKS + ACR + App Insights (Manual Deployment Method)

This guide provides step-by-step instructions for deploying a containerized application to Azure Kubernetes Service, including workarounds for common permission and authentication issues.

---

## 📋 Prerequisites

### Required Software
- ✅ Azure CLI ([Download](https://docs.microsoft.com/cli/azure/install-azure-cli))
- ✅ kubectl ([Download](https://kubernetes.io/docs/tasks/tools/))
- ✅ Git
- ✅ PowerShell or Terminal

### Azure Requirements
- ✅ Azure subscription with access
- ✅ Resource Group created
- ✅ Contributor access to the Resource Group (minimum)
- ❌ Docker Desktop **NOT REQUIRED** (we'll use ACR Build Tasks)

### Verify Installation

```powershell
# Check versions
az --version
kubectl version --client
git --version
```

---

## 🎯 Your Lab Configuration

Update these values with your actual resource names:

```powershell
$SUBSCRIPTION_ID = "20d12d83-267a-4879-842e-117791537e50"
$RESOURCE_GROUP = "sword-devops-01-rg"
$LOCATION = "eastus"
$ACR_NAME = "demoacrsword0101"
$AKS_NAME = "aksdemoswordcluster"
$APPINSIGHTS_NAME = "appinsights-aksdemosword"
```

---

## 🔧 Part 1: Setup and Authentication

### Step 1.1: Fix Azure CLI Cache Issues (If Encountered)

If you see decryption errors when running `az` commands:

```powershell
# Clear Azure CLI cache
az account clear
az cache purge

# Remove cache directory
Remove-Item -Path "$env:USERPROFILE\.azure" -Recurse -Force -ErrorAction SilentlyContinue

# Login with device code (more reliable)
az login --use-device-code

# Set subscription
az account set --subscription "20d12d83-267a-4879-842e-117791537e50"

# Verify
az account show
```

### Step 1.2: Verify Resource Group

```powershell
# Check if resource group exists
az group show --name sword-devops-01-rg

# If not, create it (requires permissions)
az group create --name sword-devops-01-rg --location eastus
```

---

## 🏗️ Part 2: Create Azure Resources

### Step 2.1: Create Azure Container Registry

```powershell
az acr create `
    --resource-group sword-devops-01-rg `
    --name demoacrsword0101 `
    --sku Basic `
    --location eastus `
    --admin-enabled true
```

**Verify:**
```powershell
az acr show --name demoacrsword0101 --resource-group sword-devops-01-rg --query loginServer -o tsv
```

### Step 2.2: Create Log Analytics Workspace

```powershell
az monitor log-analytics workspace create `
    --resource-group sword-devops-01-rg `
    --workspace-name aksdemoswordcluster-logs `
    --location eastus
```

**Get Workspace ID:**
```powershell
$workspaceId = az monitor log-analytics workspace show `
    --resource-group sword-devops-01-rg `
    --workspace-name aksdemoswordcluster-logs `
    --query id -o tsv

Write-Host "Workspace ID: $workspaceId"
```

### Step 2.3: Create Application Insights

```powershell
# Create App Insights (with workspace if available)
az monitor app-insights component create `
    --app appinsights-aksdemosword `
    --location eastus `
    --resource-group sword-devops-01-rg `
    --application-type web
```

**Get Connection String (IMPORTANT - Save This!):**
```powershell
$appInsightsCS = az monitor app-insights component show `
    --app appinsights-aksdemosword `
    --resource-group sword-devops-01-rg `
    --query connectionString -o tsv

Write-Host "`nApplication Insights Connection String:" -ForegroundColor Cyan
Write-Host $appInsightsCS -ForegroundColor Yellow
Write-Host "`nSAVE THIS - You'll need it for Kubernetes secrets!`n" -ForegroundColor Red
```

### Step 2.4: Create AKS Cluster

```powershell
az aks create `
    --resource-group sword-devops-01-rg `
    --name aksdemoswordcluster `
    --location eastus `
    --node-count 2 `
    --node-vm-size Standard_B2s `
    --enable-managed-identity `
    --attach-acr demoacrsword0101 `
    --generate-ssh-keys `
    --network-plugin azure
```

⏱️ **This takes 5-10 minutes**

**Get AKS Credentials:**
```powershell
az aks get-credentials `
    --resource-group sword-devops-01-rg `
    --name aksdemoswordcluster `
    --overwrite-existing

# Test connection
kubectl get nodes
```

---

## 🔑 Part 3: Update Configuration Files

### Step 3.1: Update Kubernetes Secret

Open: `c:\DevOps-training\Proj-1\aks-devops-project\k8s\secret.yaml`

Replace the placeholder with your actual App Insights connection string:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-secrets
  namespace: aks-demo
type: Opaque
stringData:
  appinsights-connection-string: "InstrumentationKey=YOUR_KEY_HERE;IngestionEndpoint=https://eastus-8.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=YOUR_APP_ID"
```

### Step 3.2: Verify Deployment YAML

Open: `c:\DevOps-training\Proj-1\aks-devops-project\k8s\deployment.yaml`

Ensure the image references your ACR:

```yaml
spec:
  containers:
  - name: api
    image: demoacrsword0101.azurecr.io/aks-demo-api:v1
```

---

## 🐳 Part 4: Build and Push Container Image

**No Docker Desktop Required!** We'll use Azure Container Registry Build Tasks.

### Step 4.1: Navigate to Source Directory

```powershell
cd c:\DevOps-training\Proj-1\aks-devops-project\aks-devops-project\src
```

### Step 4.2: Build Image in ACR

```powershell
# Build and push image directly in Azure
az acr build `
    --registry demoacrsword0101 `
    --image aks-demo-api:v1 `
    --file Dockerfile `
    .
```

⏱️ **This takes 2-5 minutes**

**Verify Image:**
```powershell
az acr repository list --name demoacrsword0101 -o table
az acr repository show-tags --name demoacrsword0101 --repository aks-demo-api -o table
```

### Step 4.3: Verify ACR Integration

```powershell
# Ensure AKS can pull from ACR
az aks check-acr `
    --resource-group sword-devops-01-rg `
    --name aksdemoswordcluster `
    --acr demoacrsword0101.azurecr.io
```

If integration fails:
```powershell
az aks update `
    --name aksdemoswordcluster `
    --resource-group sword-devops-01-rg `
    --attach-acr demoacrsword0101
```

---

## ☸️ Part 5: Deploy to Kubernetes

### Step 5.1: Navigate to Project Directory

```powershell
cd c:\DevOps-training\Proj-1\aks-devops-project
```

### Step 5.2: Apply Kubernetes Manifests

```powershell
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Apply ConfigMap
kubectl apply -f k8s/configmap.yaml

# Apply Secret (with App Insights connection string)
kubectl apply -f k8s/secret.yaml

# Deploy application
kubectl apply -f k8s/deployment.yaml

# Create LoadBalancer service
kubectl apply -f k8s/service.yaml
```

### Step 5.3: Monitor Deployment

```powershell
# Watch pods starting (press Ctrl+C to exit)
kubectl get pods -n aks-demo -w
```

Wait until all pods show `Running` and `1/1` ready.

**Check pod details if issues occur:**
```powershell
kubectl describe pod -n aks-demo -l app=aks-demo-api
kubectl logs -n aks-demo -l app=aks-demo-api --tail=50
```

### Step 5.4: Get External IP

```powershell
# Watch service until EXTERNAL-IP is assigned (takes 2-3 minutes)
kubectl get svc -n aks-demo -w
```

Press Ctrl+C when you see an IP address.

**Get the IP:**
```powershell
$EXTERNAL_IP = kubectl get svc aks-demo-api-service -n aks-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "`nYour Application URL: http://$EXTERNAL_IP" -ForegroundColor Green
```

---

## ✅ Part 6: Test Your Application

### Step 6.1: Test Endpoints

```powershell
# Root endpoint
curl "http://$EXTERNAL_IP"

# Health check
curl "http://$EXTERNAL_IP/api/health"

# Products API
curl "http://$EXTERNAL_IP/api/products"

# Specific product
curl "http://$EXTERNAL_IP/api/products/1"
```

### Step 6.2: Test in Browser

Open your browser and visit:
- `http://YOUR_EXTERNAL_IP`
- `http://YOUR_EXTERNAL_IP/api/health`
- `http://YOUR_EXTERNAL_IP/api/products`

---

## 📊 Part 7: Monitor with Application Insights

### Step 7.1: View Live Metrics

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to Resource Group: **sword-devops-01-rg**
3. Click on **appinsights-aksdemosword**
4. Click **Live Metrics** (left menu)
5. Make some requests to your application
6. Watch real-time telemetry!

### Step 7.2: View Logs

In Application Insights, click **Logs** and run:

```kusto
requests
| where timestamp > ago(1h)
| summarize count() by name, resultCode
| order by count_ desc
```

### Step 7.3: Application Map

Click **Application Map** to see your application architecture and dependencies.

---

## 🔄 Part 8: Update Your Application

### Step 8.1: Make Code Changes

Edit any file in: `aks-devops-project\aks-devops-project\src\api\`

### Step 8.2: Rebuild Image

```powershell
cd c:\DevOps-training\Proj-1\aks-devops-project\aks-devops-project\src

# Build with new tag
az acr build `
    --registry demoacrsword0101 `
    --image aks-demo-api:v2 `
    --file Dockerfile `
    .
```

### Step 8.3: Update Deployment

```powershell
cd c:\DevOps-training\Proj-1\aks-devops-project

# Update image
kubectl set image deployment/aks-demo-api -n aks-demo api=demoacrsword0101.azurecr.io/aks-demo-api:v2

# Watch rolling update
kubectl rollout status deployment/aks-demo-api -n aks-demo
```

---

## 🛠️ Part 9: Useful Commands

### View Resources

```powershell
# All resources in namespace
kubectl get all -n aks-demo

# Detailed pod information
kubectl describe pod -n aks-demo <pod-name>

# View logs
kubectl logs -n aks-demo <pod-name>
kubectl logs -n aks-demo -l app=aks-demo-api --tail=100

# View events
kubectl get events -n aks-demo --sort-by='.lastTimestamp'

# Get into a pod
kubectl exec -it -n aks-demo <pod-name> -- /bin/bash
```

### Scale Application

```powershell
# Scale to 5 replicas
kubectl scale deployment aks-demo-api -n aks-demo --replicas=5

# Scale back to 3
kubectl scale deployment aks-demo-api -n aks-demo --replicas=3

# Auto-scale
kubectl autoscale deployment aks-demo-api -n aks-demo --cpu-percent=50 --min=2 --max=10
```

### Rollback Deployment

```powershell
# View rollout history
kubectl rollout history deployment/aks-demo-api -n aks-demo

# Rollback to previous version
kubectl rollout undo deployment/aks-demo-api -n aks-demo

# Rollback to specific revision
kubectl rollout undo deployment/aks-demo-api -n aks-demo --to-revision=2
```

### View Azure Resources

```powershell
# List all resources in resource group
az resource list --resource-group sword-devops-01-rg -o table

# AKS node pool information
az aks nodepool list --resource-group sword-devops-01-rg --cluster-name aksdemoswordcluster -o table

# ACR repositories
az acr repository list --name demoacrsword0101 -o table

# Get AKS dashboard token
az aks get-credentials --resource-group sword-devops-01-rg --name aksdemoswordcluster --admin
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep aks-admin | awk '{print $1}')
```

---

## 🐛 Troubleshooting Guide

### Issue 1: Pods in ImagePullBackOff

**Symptoms:**
```
aks-demo-api-xxx   0/1   ImagePullBackOff   0   5m
```

**Solutions:**

```powershell
# 1. Check if image exists in ACR
az acr repository show-tags --name demoacrsword0101 --repository aks-demo-api -o table

# 2. Verify ACR integration
az aks check-acr --resource-group sword-devops-01-rg --name aksdemoswordcluster --acr demoacrsword0101.azurecr.io

# 3. Re-attach ACR to AKS
az aks update --name aksdemoswordcluster --resource-group sword-devops-01-rg --attach-acr demoacrsword0101

# 4. Check deployment image reference
kubectl describe deployment aks-demo-api -n aks-demo | Select-String "Image:"

# 5. Update deployment with correct image
kubectl set image deployment/aks-demo-api -n aks-demo api=demoacrsword0101.azurecr.io/aks-demo-api:v1
```

### Issue 2: Pods in CrashLoopBackOff

**Symptoms:**
```
aks-demo-api-xxx   0/1   CrashLoopBackOff   3   2m
```

**Solutions:**

```powershell
# View pod logs
kubectl logs -n aks-demo -l app=aks-demo-api --tail=100

# Describe pod for events
kubectl describe pod -n aks-demo -l app=aks-demo-api

# Check if App Insights connection string is set
kubectl get secret api-secrets -n aks-demo -o yaml
```

### Issue 3: Service Has No External IP

**Symptoms:**
```
aks-demo-api-service   LoadBalancer   <pending>   80:31234/TCP   10m
```

**Solutions:**

```powershell
# Wait 2-3 minutes, it takes time to provision

# Check service details
kubectl describe svc aks-demo-api-service -n aks-demo

# Check Azure Load Balancer
az network lb list --resource-group MC_sword-devops-01-rg_aksdemoswordcluster_eastus -o table

# If stuck after 5 minutes, delete and recreate service
kubectl delete svc aks-demo-api-service -n aks-demo
kubectl apply -f k8s/service.yaml
```

### Issue 4: Azure CLI Authentication Errors

**Symptoms:**
```
Decryption failed: [WinError -2146893813] Key not valid for use in specified state
```

**Solutions:**

```powershell
# Clear cache and re-login
az account clear
Remove-Item -Path "$env:USERPROFILE\.azure" -Recurse -Force -ErrorAction SilentlyContinue
az login --use-device-code
az account set --subscription "20d12d83-267a-4879-842e-117791537e50"
```

### Issue 5: Cannot Create Service Principal

**Symptoms:**
```
AuthorizationFailed: The client does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'
```

**Solutions:**

This means you don't have Owner permissions. Options:

1. **Contact your Azure admin** to give you Owner role
2. **Ask admin to create service principal** for you
3. **Use manual deployment** (as shown in this guide - no service principal needed!)

### Issue 6: ACR Build Fails

**Solutions:**

```powershell
# Check ACR service is running
az acr show --name demoacrsword0101 --query "status"

# Verify Dockerfile exists
Test-Path c:\DevOps-training\Proj-1\aks-devops-project\aks-devops-project\src\Dockerfile

# Check ACR admin is enabled
az acr update --name demoacrsword0101 --admin-enabled true

# Try build again with verbose output
az acr build --registry demoacrsword0101 --image aks-demo-api:v1 --file Dockerfile . --debug
```

---

## 🧹 Cleanup

### Option 1: Delete Kubernetes Resources Only

```powershell
# Delete namespace (removes all resources in it)
kubectl delete namespace aks-demo
```

### Option 2: Delete Entire Resource Group

⚠️ **WARNING: This deletes ALL resources!**

```powershell
az group delete --name sword-devops-01-rg --yes --no-wait
```

### Option 3: Delete Specific Resources

```powershell
# Delete AKS cluster
az aks delete --name aksdemoswordcluster --resource-group sword-devops-01-rg --yes --no-wait

# Delete ACR
az acr delete --name demoacrsword0101 --resource-group sword-devops-01-rg --yes

# Delete App Insights
az monitor app-insights component delete --app appinsights-aksdemosword --resource-group sword-devops-01-rg

# Delete Log Analytics
az monitor log-analytics workspace delete --workspace-name aksdemoswordcluster-logs --resource-group sword-devops-01-rg --yes
```

---

## 📝 Quick Reference

### Your Resources

| Resource Type | Name | Purpose |
|---------------|------|---------|
| Resource Group | sword-devops-01-rg | Container for all resources |
| ACR | demoacrsword0101 | Container registry |
| AKS | aksdemoswordcluster | Kubernetes cluster |
| App Insights | appinsights-aksdemosword | Application monitoring |
| Log Analytics | aksdemoswordcluster-logs | Logs storage |

### Key Commands Cheat Sheet

```powershell
# Build image in ACR
az acr build --registry demoacrsword0101 --image aks-demo-api:v1 .

# Get AKS credentials
az aks get-credentials --resource-group sword-devops-01-rg --name aksdemoswordcluster --overwrite-existing

# Deploy to Kubernetes
kubectl apply -f k8s/

# Get external IP
kubectl get svc -n aks-demo

# View pods
kubectl get pods -n aks-demo

# View logs
kubectl logs -n aks-demo -l app=aks-demo-api

# Scale
kubectl scale deployment aks-demo-api -n aks-demo --replicas=5

# Update image
kubectl set image deployment/aks-demo-api -n aks-demo api=demoacrsword0101.azurecr.io/aks-demo-api:v2
```

---

## 🎓 What You've Learned

✅ Created and configured Azure Container Registry (ACR)  
✅ Built container images using ACR Build Tasks (no local Docker needed)  
✅ Created and configured Azure Kubernetes Service (AKS)  
✅ Integrated Application Insights for monitoring  
✅ Deployed applications to Kubernetes using kubectl  
✅ Configured Kubernetes resources (Deployments, Services, ConfigMaps, Secrets)  
✅ Exposed applications using LoadBalancer services  
✅ Monitored applications with Application Insights  
✅ Performed rolling updates and rollbacks  
✅ Troubleshot common Kubernetes and Azure issues  

---

## 📚 Additional Resources

- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/azure/container-registry/)
- [Application Insights Documentation](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

## ✅ Lab Completion Checklist

- [ ] Azure CLI installed and authenticated
- [ ] Resource Group created
- [ ] ACR created and accessible
- [ ] AKS cluster created with 2 nodes
- [ ] Application Insights created and connection string saved
- [ ] Container image built and pushed to ACR
- [ ] Kubernetes manifests applied successfully
- [ ] All pods running (3/3)
- [ ] Service has external IP assigned
- [ ] Application accessible via browser
- [ ] All API endpoints responding correctly
- [ ] Application Insights receiving telemetry
- [ ] Tested scaling and updates

---

**Congratulations! 🎉** You've successfully deployed a containerized application to Azure Kubernetes Service with monitoring!

---

**Version:** 2.0  
**Last Updated:** December 16, 2025  
**Tested With:** Azure CLI 2.x, kubectl 1.28+, AKS 1.28+
