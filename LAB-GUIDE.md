# 🚀 Hands-on Lab: Deploy AKS + ACR + App Insights + Azure DevOps

## Lab Overview
Deploy a containerized ASP.NET Core API to Azure Kubernetes Service (AKS) with Azure Container Registry (ACR) and Application Insights monitoring using Azure DevOps CI/CD pipeline.

**Duration:** 60-90 minutes

---

## 📋 Prerequisites

Before starting, ensure you have:

- ✅ Azure subscription with contributor access
- ✅ Azure DevOps organization and project
- ✅ Repository cloned locally
- ✅ Azure CLI installed ([Download](https://docs.microsoft.com/cli/azure/install-azure-cli))
- ✅ Docker Desktop installed ([Download](https://www.docker.com/products/docker-desktop))
- ✅ kubectl installed ([Download](https://kubernetes.io/docs/tasks/tools/))
- ✅ Git installed
- ✅ Resource Group created in Azure Portal

### Verify Prerequisites

Open PowerShell and run:

```powershell
# Check Azure CLI
az --version

# Check Docker
docker --version

# Check kubectl
kubectl version --client

# Check Git
git --version
```

---

## 🎯 Lab Architecture

```
┌─────────────────────────────────────────────────┐
│           Azure DevOps Pipeline                  │
│  (Build → Push to ACR → Deploy to AKS)         │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│              Azure Resources                     │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐ │
│  │   ACR    │  │   AKS    │  │ App Insights │ │
│  │          │  │          │  │              │ │
│  │ Container│◄─┤ Kubernetes│─►│  Monitoring  │ │
│  │ Registry │  │ Cluster  │  │              │ │
│  └──────────┘  └──────────┘  └──────────────┘ │
└─────────────────────────────────────────────────┘
```

---

## 📝 Step-by-Step Instructions

### **STEP 1: Verify Your Project Structure**

Your project should now have this structure:

```
aks-devops-project/
├── aks-devops-project/
│   └── src/
│       ├── api/
│       │   ├── Controllers/
│       │   │   ├── HealthController.cs
│       │   │   └── ProductsController.cs
│       │   ├── api.csproj
│       │   ├── appsettings.json
│       │   └── Program.cs
│       ├── Dockerfile
│       └── .dockerignore
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── scripts/
│   └── setup-azure-resources.ps1
└── azure-pipelines.yml
```

✅ All files have been created for you!

---

### **STEP 2: Login to Azure**

Open PowerShell and login:

```powershell
# Login to Azure
az login

# Verify your subscription
az account show

# If you have multiple subscriptions, set the correct one:
# az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

---

### **STEP 3: Create Azure Resources**

Now let's create ACR, AKS, and Application Insights.

**Set your variables:**

```powershell
# Navigate to your project
cd c:\DevOps-training\Proj-1\aks-devops-project

# Set your variables (UPDATE THESE!)
$RG = "rg-aks-lab"                                    # Your existing or new RG name
$LOCATION = "eastus"                                   # Azure region
$ACR_NAME = "acraksdemo$(Get-Random -Maximum 9999)"   # Must be unique globally
$AKS_NAME = "aks-demo-cluster"                        # Your AKS cluster name
$APPINSIGHTS_NAME = "appinsights-aks-demo"            # App Insights name

# Display your configuration
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "Resource Group: $RG"
Write-Host "Location: $LOCATION"
Write-Host "ACR Name: $ACR_NAME"
Write-Host "AKS Name: $AKS_NAME"
Write-Host "App Insights: $APPINSIGHTS_NAME"
Write-Host ""
Read-Host "Press Enter to continue or Ctrl+C to cancel"
```

**Run the setup script:**

```powershell
.\scripts\setup-azure-resources.ps1 `
    -ResourceGroupName $RG `
    -Location $LOCATION `
    -AcrName $ACR_NAME `
    -AksName $AKS_NAME `
    -AppInsightsName $APPINSIGHTS_NAME
```

⏱️ **This will take 5-10 minutes.** The script will:
- Create/verify Resource Group
- Create Azure Container Registry (ACR)
- Create Log Analytics Workspace
- Create Application Insights
- Create AKS cluster with 2 nodes
- Attach ACR to AKS
- Configure kubectl

**🔑 IMPORTANT:** At the end, the script will display the **Application Insights Connection String**. Copy and save it!

Example output:
```
Application Insights Connection String:
InstrumentationKey=12345678-1234-1234-1234-123456789abc;IngestionEndpoint=https://...
```

---

### **STEP 4: Update Configuration Files**

#### 4.1 Update the Secret with App Insights Connection String

Open [k8s/secret.yaml](k8s/secret.yaml) and replace `YOUR_APP_INSIGHTS_CONNECTION_STRING_HERE` with your actual connection string:

```yaml
stringData:
  appinsights-connection-string: "InstrumentationKey=12345678-1234-1234-1234-123456789abc;IngestionEndpoint=https://..."
```

#### 4.2 Update Deployment with ACR Name

Open [k8s/deployment.yaml](k8s/deployment.yaml) and replace `YOUR_ACR_NAME` with your actual ACR name:

```yaml
image: acraksdemo1234.azurecr.io/aks-demo-api:latest
```

**💡 Tip:** Your ACR login server was displayed in the setup script output (e.g., `acraksdemo1234.azurecr.io`)

---

### **STEP 5: Test Docker Build Locally (Optional)**

Before pushing to Azure DevOps, test the Docker build:

```powershell
# Navigate to the src directory
cd aks-devops-project\aks-devops-project\src

# Build the Docker image
docker build -t aks-demo-api:local -f Dockerfile .

# Run the container
docker run -d -p 8080:80 --name aks-test aks-demo-api:local

# Test the endpoints
Start-Sleep -Seconds 5
curl http://localhost:8080
curl http://localhost:8080/api/health
curl http://localhost:8080/api/products

# Stop and remove the container
docker stop aks-test
docker rm aks-test

# Go back to project root
cd ..\..\..
```

✅ If successful, you should see JSON responses!

---

### **STEP 6: Push Code to Azure DevOps**

```powershell
# Add all files
git add .

# Commit changes
git commit -m "Add AKS deployment lab files"

# Push to Azure DevOps
git push origin main
```

---

### **STEP 7: Create Azure Service Connection**

1. Go to your Azure DevOps project
2. Navigate to **Project Settings** (bottom left)
3. Under **Pipelines**, click **Service connections**
4. Click **New service connection**
5. Select **Azure Resource Manager** → **Next**
6. Select **Service principal (automatic)** → **Next**
7. Fill in:
   - **Subscription**: Select your Azure subscription
   - **Resource group**: Select your resource group (e.g., `rg-aks-lab`)
   - **Service connection name**: `azure-aks-connection`
   - ✅ Check **Grant access permission to all pipelines**
8. Click **Save**

✅ Note the service connection name - you'll need it in the next step!

---

### **STEP 8: Update Pipeline Variables**

Open [azure-pipelines.yml](azure-pipelines.yml) and update the variables section:

```yaml
variables:
  azureSubscription: 'azure-aks-connection'         # Your service connection name
  resourceGroup: 'rg-aks-lab'                       # Your resource group
  acrName: 'acraksdemo1234'                         # Your ACR name (NO .azurecr.io)
  aksClusterName: 'aks-demo-cluster'                # Your AKS name
  appInsightsConnectionString: 'InstrumentationKey=...' # Your App Insights connection string
```

**Save and commit:**

```powershell
git add azure-pipelines.yml
git commit -m "Update pipeline variables"
git push origin main
```

---

### **STEP 9: Create and Run Azure DevOps Pipeline**

1. Go to **Pipelines** → **Pipelines**
2. Click **New pipeline** (or **Create Pipeline**)
3. Select **Azure Repos Git**
4. Select your repository
5. Select **Existing Azure Pipelines YAML file**
6. Choose `/azure-pipelines.yml`
7. Click **Continue**
8. Review the pipeline
9. Click **Run**

⏱️ **The pipeline will take 5-10 minutes** to complete.

**Pipeline stages:**
1. **Build**: Build Docker image and push to ACR
2. **Deploy**: Deploy to AKS using kubectl

---

### **STEP 10: Monitor the Deployment**

While the pipeline runs, open a new PowerShell window:

```powershell
# Ensure kubectl is configured
az aks get-credentials --resource-group rg-aks-lab --name aks-demo-cluster --overwrite-existing

# Watch pods being created
kubectl get pods -n aks-demo -w

# In another terminal, watch the service
kubectl get svc -n aks-demo -w
```

Wait for:
- ✅ Pods: `Running` and `Ready 1/1`
- ✅ Service: External IP assigned (not `<pending>`)

Press `Ctrl+C` to stop watching.

---

### **STEP 11: Get the Application URL**

```powershell
# Get the external IP
$EXTERNAL_IP = kubectl get svc aks-demo-api-service -n aks-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "🎉 Application is running at:" -ForegroundColor Green
Write-Host "   http://$EXTERNAL_IP" -ForegroundColor Cyan
Write-Host "   http://$EXTERNAL_IP/api/health" -ForegroundColor Cyan
Write-Host "   http://$EXTERNAL_IP/api/products" -ForegroundColor Cyan
```

---

### **STEP 12: Test the Application**

```powershell
# Test the root endpoint
curl "http://$EXTERNAL_IP"

# Test health check
curl "http://$EXTERNAL_IP/api/health"

# Test products API
curl "http://$EXTERNAL_IP/api/products"

# Test specific product
curl "http://$EXTERNAL_IP/api/products/1"
```

You can also open these URLs in your browser!

---

### **STEP 13: View Application Insights**

1. Go to **Azure Portal** (portal.azure.com)
2. Navigate to your Resource Group
3. Click on **Application Insights** resource
4. Explore:
   - **Live Metrics**: Real-time telemetry
   - **Application Map**: Service dependencies
   - **Performance**: Response times
   - **Failures**: Error tracking
   - **Logs**: Query application logs

**Sample query in Logs:**

```kusto
requests
| where timestamp > ago(1h)
| summarize count() by name, resultCode
| order by count_ desc
```

---

### **STEP 14: Explore Kubernetes**

```powershell
# View all resources
kubectl get all -n aks-demo

# View pod details
kubectl describe pod -n aks-demo -l app=aks-demo-api

# View logs
kubectl logs -n aks-demo -l app=aks-demo-api --tail=50

# View logs for a specific pod
kubectl logs -n aks-demo <pod-name>

# Get pod names
kubectl get pods -n aks-demo

# Execute commands in a pod
kubectl exec -it -n aks-demo <pod-name> -- /bin/bash

# View events
kubectl get events -n aks-demo --sort-by='.lastTimestamp'
```

---

## 🎓 Advanced Tasks (Optional)

### Task 1: Scale the Application

```powershell
# Scale to 5 replicas
kubectl scale deployment aks-demo-api -n aks-demo --replicas=5

# Watch the scaling
kubectl get pods -n aks-demo -w

# Scale back to 3
kubectl scale deployment aks-demo-api -n aks-demo --replicas=3
```

### Task 2: Update the Application

1. Make a change to [HealthController.cs](aks-devops-project/aks-devops-project/src/api/Controllers/HealthController.cs)
2. Commit and push
3. Pipeline will automatically trigger
4. Watch the rolling update:

```powershell
kubectl rollout status deployment/aks-demo-api -n aks-demo
```

### Task 3: View Deployment History

```powershell
# View rollout history
kubectl rollout history deployment/aks-demo-api -n aks-demo

# Rollback to previous version
kubectl rollout undo deployment/aks-demo-api -n aks-demo
```

### Task 4: Configure HPA (Horizontal Pod Autoscaler)

```powershell
# Create HPA
kubectl autoscale deployment aks-demo-api -n aks-demo --cpu-percent=50 --min=2 --max=10

# View HPA
kubectl get hpa -n aks-demo
```

---

## 🧹 Cleanup

When you're done with the lab:

```powershell
# Delete Kubernetes resources
kubectl delete namespace aks-demo

# Delete Azure resources (this will delete EVERYTHING in the RG)
az group delete --name rg-aks-lab --yes --no-wait
```

⚠️ **Warning**: This will delete all resources in the resource group!

---

## 🐛 Troubleshooting

### Pods not starting?

```powershell
# Describe pod to see events
kubectl describe pod -n aks-demo -l app=aks-demo-api

# Check logs
kubectl logs -n aks-demo -l app=aks-demo-api --tail=100
```

### Can't pull image from ACR?

```powershell
# Verify ACR integration
az aks check-acr --resource-group rg-aks-lab --name aks-demo-cluster --acr acraksdemo1234.azurecr.io

# Re-attach ACR
az aks update --name aks-demo-cluster --resource-group rg-aks-lab --attach-acr acraksdemo1234
```

### Service has no external IP?

```powershell
# Check service status
kubectl get svc -n aks-demo

# Describe service
kubectl describe svc aks-demo-api-service -n aks-demo

# Check Azure Load Balancer (may take 2-3 minutes)
az network lb list --resource-group MC_rg-aks-lab_aks-demo-cluster_eastus -o table
```

### Pipeline failing?

1. Check service connection has correct permissions
2. Verify variable values in pipeline
3. Check pipeline logs for specific errors
4. Ensure kubectl context is correct

---

## ✅ Lab Completion Checklist

- [ ] Azure resources created (ACR, AKS, App Insights)
- [ ] Docker image built and pushed to ACR
- [ ] Azure DevOps pipeline created and run successfully
- [ ] Application deployed to AKS
- [ ] 3 pods running in AKS
- [ ] LoadBalancer service has external IP
- [ ] Application accessible via browser
- [ ] All API endpoints responding correctly
- [ ] Application Insights receiving telemetry data
- [ ] Can view logs and metrics in Azure Portal

---

## 📚 Key Concepts Learned

✅ **Containerization**: Dockerized an ASP.NET Core application
✅ **Container Registry**: Stored container images in ACR
✅ **Kubernetes**: Deployed application to AKS cluster
✅ **CI/CD**: Automated build and deployment with Azure DevOps
✅ **Monitoring**: Integrated Application Insights for observability
✅ **Infrastructure**: Managed Kubernetes infrastructure in Azure
✅ **DevOps**: Full DevOps workflow from code to production

---

## 🎉 Congratulations!

You've successfully completed the **AKS + ACR + App Insights + Azure DevOps** hands-on lab!

You now have a production-ready containerized application running on Kubernetes with full CI/CD automation and monitoring.

---

## 📖 Additional Resources

- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/azure/container-registry/)
- [Application Insights Documentation](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Azure DevOps Pipelines Documentation](https://docs.microsoft.com/azure/devops/pipelines/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

**Questions or Issues?** Check the troubleshooting section or review the Azure DevOps pipeline logs.
