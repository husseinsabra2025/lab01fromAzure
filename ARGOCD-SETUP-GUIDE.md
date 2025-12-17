# 🚀 ArgoCD Installation & Configuration Guide for AKS

**Lab:** Install ArgoCD on Azure Kubernetes Service  
**Cluster:** aksdemoswordcluster  
**Date:** December 2025

---

## 📋 Prerequisites

✅ AKS cluster running (aksdemoswordcluster)  
✅ kubectl configured and connected to AKS  
✅ Azure CLI installed  
✅ Git repository (Azure DevOps or GitHub)

**Verify Prerequisites:**

```powershell
# Check kubectl connection
kubectl get nodes

# Verify you're on the right cluster
kubectl config current-context
```

---

## 🔧 Part 1: Install ArgoCD

### Step 1.1: Create ArgoCD Namespace

```powershell
kubectl create namespace argocd
```

### Step 1.2: Install ArgoCD

```powershell
# Install ArgoCD manifests
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

⏱️ **This takes 2-3 minutes to deploy all components**

### Step 1.3: Verify Installation

```powershell
# Watch pods until all are running
kubectl get pods -n argocd -w
```

Wait until all pods show `Running` and `1/1` or `2/2` ready. Press Ctrl+C to stop watching.

**Expected pods:**
- argocd-application-controller
- argocd-applicationset-controller
- argocd-dex-server
- argocd-notifications-controller
- argocd-redis
- argocd-repo-server
- argocd-server

```powershell
# Verify all pods are running
kubectl get pods -n argocd

# Check services
kubectl get svc -n argocd
```

---

## 🌐 Part 2: Access ArgoCD UI

### Option 1: LoadBalancer (Recommended for Production)

```powershell
# Change argocd-server service to LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'

# Wait for external IP (takes 2-3 minutes)
kubectl get svc argocd-server -n argocd -w
```

Press Ctrl+C when you see the EXTERNAL-IP.

```powershell
# Get the external IP
$ARGOCD_IP = kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "ArgoCD URL: https://$ARGOCD_IP" -ForegroundColor Green
```

### Option 2: Port Forward (Quick Testing)

```powershell
# Port forward to localhost (run in separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
```

### Option 3: Ingress (Advanced - Not Covered Here)

---

## 🔑 Part 3: Get ArgoCD Initial Password

### Step 3.1: Retrieve Admin Password

```powershell
# Get the initial admin password
$ARGOCD_PASSWORD = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "`nArgoCD Login Credentials:" -ForegroundColor Cyan
Write-Host "Username: admin" -ForegroundColor White
Write-Host "Password: $ARGOCD_PASSWORD" -ForegroundColor Yellow
Write-Host "`nSave these credentials!`n" -ForegroundColor Red
```

### Step 3.2: Login to ArgoCD UI

1. Open browser and go to: `https://YOUR_EXTERNAL_IP`
2. Accept the self-signed certificate warning
3. Login with:
   - **Username:** `admin`
   - **Password:** (from above command)

---

## 💻 Part 4: Install ArgoCD CLI (Optional but Recommended)

### Windows Installation:

```powershell
# Using Chocolatey
choco install argocd-cli

# Or using Scoop
scoop install argocd

# Or download directly
$version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
$url = "https://github.com/argoproj/argo-cd/releases/download/$version/argocd-windows-amd64.exe"
Invoke-WebRequest -Uri $url -OutFile "$env:ProgramFiles\argocd.exe"
```

### Verify Installation:

```powershell
argocd version
```

### Login via CLI:

```powershell
# Login to ArgoCD
argocd login $ARGOCD_IP --username admin --password $ARGOCD_PASSWORD --insecure

# Or interactive
argocd login $ARGOCD_IP --insecure
```

---

## 🔐 Part 5: Configure Git Repository

### Option A: Azure DevOps Repository

#### Step 5.1: Create Personal Access Token (PAT)

1. Go to Azure DevOps → User Settings → Personal Access Tokens
2. Click **New Token**
3. Name: "ArgoCD Access"
4. Scopes: **Code (Read)**
5. Create and **copy the token**

#### Step 5.2: Add Repository via CLI

```powershell
# Add Azure DevOps repo
argocd repo add https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_git/YOUR_REPO `
    --username YOUR_EMAIL `
    --password YOUR_PAT_TOKEN `
    --insecure-skip-server-verification
```

#### Step 5.3: Add Repository via UI

1. Go to ArgoCD UI → **Settings** → **Repositories**
2. Click **Connect Repo**
3. Choose **VIA HTTPS**
4. Fill in:
   - **Type:** git
   - **Project:** default
   - **Repository URL:** `https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_git/YOUR_REPO`
   - **Username:** Your Azure DevOps email
   - **Password:** Your PAT token
5. Click **Connect**

### Option B: GitHub Repository

#### Step 5.1: Create GitHub Token

1. GitHub → Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Scopes: **repo (all)**
4. Copy token

#### Step 5.2: Add GitHub Repo

```powershell
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO.git `
    --username YOUR_GITHUB_USERNAME `
    --password YOUR_GITHUB_TOKEN `
    --insecure-skip-server-verification
```

---

## 📦 Part 6: Deploy Your Application with ArgoCD

### Step 6.1: Prepare Your Git Repository Structure

Your repo should have this structure:

```
your-repo/
├── aks-devops-project/
│   └── k8s/
│       ├── namespace.yaml
│       ├── configmap.yaml
│       ├── secret.yaml
│       ├── deployment.yaml
│       └── service.yaml
```

### Step 6.2: Create ArgoCD Application (via CLI)

```powershell
argocd app create aks-demo-app `
    --repo https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_git/YOUR_REPO `
    --path aks-devops-project/k8s `
    --dest-server https://kubernetes.default.svc `
    --dest-namespace aks-demo `
    --sync-policy automated `
    --auto-prune `
    --self-heal `
    --insecure
```

### Step 6.3: Create ArgoCD Application (via UI)

1. Click **+ NEW APP** in ArgoCD UI
2. Fill in **GENERAL** section:
   - **Application Name:** `aks-demo-app`
   - **Project:** `default`
   - **Sync Policy:** `Automatic`
   - ✅ Check **Prune Resources**
   - ✅ Check **Self Heal**

3. Fill in **SOURCE** section:
   - **Repository URL:** Your repo URL
   - **Revision:** `main` or `master`
   - **Path:** `aks-devops-project/k8s`

4. Fill in **DESTINATION** section:
   - **Cluster URL:** `https://kubernetes.default.svc`
   - **Namespace:** `aks-demo`

5. Click **CREATE**

### Step 6.4: Sync Application

```powershell
# Sync via CLI
argocd app sync aks-demo-app

# Watch sync status
argocd app wait aks-demo-app --health
```

Or click **SYNC** in the UI.

---

## 🔍 Part 7: Verify Deployment

### Check ArgoCD Application Status:

```powershell
# Via CLI
argocd app list
argocd app get aks-demo-app

# Via kubectl
kubectl get pods -n aks-demo
kubectl get svc -n aks-demo
```

### Access Application:

```powershell
# Get your app's external IP
kubectl get svc aks-demo-api-service -n aks-demo
```

---

## 🎨 Part 8: ArgoCD UI Overview

### Main Components:

1. **Applications** - View all deployed apps
2. **Settings** - Configure repos, clusters, projects
3. **User Info** - Change password, logout

### Application View:

- **Green = Healthy** - All resources running
- **Yellow = Progressing** - Deployment in progress
- **Red = Degraded** - Issues detected
- **Synced** - Git matches cluster
- **OutOfSync** - Git differs from cluster

### Useful UI Actions:

- **Sync** - Deploy latest changes from Git
- **Refresh** - Re-check Git repository
- **Diff** - See differences between Git and cluster
- **Details** - View resource manifests
- **Events** - See deployment events
- **Logs** - View pod logs

---

## 🔄 Part 9: GitOps Workflow

### How It Works:

```
1. Make changes to k8s YAML files
2. Commit and push to Git
3. ArgoCD detects changes (auto-sync)
4. ArgoCD applies changes to AKS
5. Verify in ArgoCD UI
```

### Example: Update Your App

```powershell
# 1. Edit deployment.yaml (change replica count)
cd c:\DevOps-training\Proj-1\aks-devops-project\k8s

# Edit deployment.yaml - change replicas: 3 to replicas: 5

# 2. Commit and push
git add k8s/deployment.yaml
git commit -m "Scale app to 5 replicas"
git push origin main

# 3. Watch ArgoCD sync (automatic if configured)
argocd app wait aks-demo-app --sync

# 4. Verify
kubectl get pods -n aks-demo
```

---

## 🛡️ Part 10: Secure ArgoCD

### Step 10.1: Change Admin Password

```powershell
# Via CLI
argocd account update-password

# Or via UI: User Info → Update Password
```

### Step 10.2: Delete Initial Secret

```powershell
# After changing password, delete the initial secret
kubectl -n argocd delete secret argocd-initial-admin-secret
```

### Step 10.3: Enable TLS (Production)

For production, configure proper TLS certificate:

```powershell
# Create TLS secret
kubectl create secret tls argocd-server-tls `
    --cert=path/to/cert.crt `
    --key=path/to/cert.key `
    -n argocd
```

---

## 🔧 Part 11: Useful ArgoCD Commands

### Application Management:

```powershell
# List all applications
argocd app list

# Get application details
argocd app get aks-demo-app

# Sync application
argocd app sync aks-demo-app

# Delete application
argocd app delete aks-demo-app

# View application logs
argocd app logs aks-demo-app

# View application history
argocd app history aks-demo-app

# Rollback to previous version
argocd app rollback aks-demo-app 1
```

### Repository Management:

```powershell
# List repositories
argocd repo list

# Add repository
argocd repo add REPO_URL --username USER --password PASS

# Remove repository
argocd repo rm REPO_URL
```

### Cluster Management:

```powershell
# List clusters
argocd cluster list

# Add cluster
argocd cluster add CONTEXT_NAME

# Remove cluster
argocd cluster rm CONTEXT_NAME
```

---

## 📊 Part 12: Monitor with Application Insights

### Update Your Deployment for ArgoCD Annotations

Add ArgoCD annotations to your deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aks-demo-api
  namespace: aks-demo
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    argocd.argoproj.io/hook: Sync
  labels:
    app: aks-demo-api
    app.kubernetes.io/name: aks-demo-api
    app.kubernetes.io/instance: aks-demo-app
spec:
  # ... rest of deployment
```

---

## 🐛 Troubleshooting

### Issue 1: Can't Access ArgoCD UI

```powershell
# Check service
kubectl get svc argocd-server -n argocd

# Check pods
kubectl get pods -n argocd

# View logs
kubectl logs -n argocd deployment/argocd-server
```

### Issue 2: Application Stuck in "Progressing"

```powershell
# Check application details
argocd app get aks-demo-app

# View events
kubectl get events -n aks-demo --sort-by='.lastTimestamp'

# Check pod status
kubectl describe pod -n aks-demo -l app=aks-demo-api
```

### Issue 3: "OutOfSync" Status

```powershell
# View differences
argocd app diff aks-demo-app

# Force sync
argocd app sync aks-demo-app --force

# Or delete and recreate
kubectl delete -f k8s/deployment.yaml
argocd app sync aks-demo-app
```

### Issue 4: Can't Connect to Repository

```powershell
# Test connection
argocd repo get REPO_URL

# Re-add repository with correct credentials
argocd repo rm REPO_URL
argocd repo add REPO_URL --username USER --password PASS
```

---

## 🎯 Part 13: Advanced Features

### App of Apps Pattern

Create a parent app that manages multiple child apps:

```yaml
# apps/parent-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: parent-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://your-repo-url
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Multi-Environment Setup

```
repo/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── production/
│       └── kustomization.yaml
```

Create separate ArgoCD apps for each environment.

---

## 🧹 Cleanup

### Uninstall ArgoCD (if needed):

```powershell
# Delete ArgoCD namespace (removes everything)
kubectl delete namespace argocd

# Or delete specific resources
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

---

## 📚 Quick Reference

### Essential URLs:

- **ArgoCD UI:** `https://YOUR_EXTERNAL_IP`
- **ArgoCD Docs:** https://argo-cd.readthedocs.io/
- **ArgoCD GitHub:** https://github.com/argoproj/argo-cd

### Key Concepts:

| Term | Description |
|------|-------------|
| **Application** | Kubernetes resources managed by ArgoCD |
| **Project** | Logical grouping of applications |
| **Sync** | Apply Git state to cluster |
| **Refresh** | Check Git for changes |
| **Health** | Status of Kubernetes resources |
| **Prune** | Delete resources not in Git |
| **Self-Heal** | Auto-sync when drift detected |

---

## ✅ Checklist

- [ ] ArgoCD installed on AKS
- [ ] All ArgoCD pods running
- [ ] ArgoCD UI accessible
- [ ] Admin password changed
- [ ] Git repository connected
- [ ] First application deployed
- [ ] Application synced and healthy
- [ ] GitOps workflow tested
- [ ] Monitoring configured

---

## 🎉 Success!

You now have ArgoCD running on your AKS cluster with GitOps enabled!

**Next Steps:**
1. Configure multiple environments (dev/staging/prod)
2. Set up RBAC for team members
3. Enable notifications (Slack, Teams, etc.)
4. Configure webhooks for faster sync
5. Implement progressive delivery with Argo Rollouts

---

**Version:** 1.0  
**Last Updated:** December 17, 2025  
**Tested With:** ArgoCD 2.9+, AKS 1.28+
