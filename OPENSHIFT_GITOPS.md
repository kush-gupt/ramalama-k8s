# OpenShift GitOps Deployment Guide

This guide helps you deploy Ramalama models and OpenShift Lightspeed using OpenShift GitOps (Red Hat's ArgoCD distribution).

## Prerequisites

1. **OpenShift 4.15+** cluster with admin access
2. **OpenShift GitOps operator** installed
3. **Git repository** with your ramalama-k8s configuration

## Step 1: Install OpenShift GitOps

If OpenShift GitOps is not already installed:

```bash
# Install OpenShift GitOps operator
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: gitops-1.14
  installPlanApproval: Automatic
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait for operator to be ready
oc get csv -n openshift-gitops-operator -w

# Verify GitOps is running
oc get pods -n openshift-gitops
```

## Step 2: Deploy Models with GitOps

### Option A: Deploy All Models (ApplicationSet)

```bash
# Deploy all ramalama models across environments
oc apply -f k8s/argocd/applicationset-example.yaml

# Monitor deployment (all models go to ramalama namespace)
oc get applications -n openshift-gitops -w
oc get pods -n ramalama -w
```

### Option B: Deploy Single Model

```bash
# Deploy specific model
oc apply -f k8s/argocd/application-example.yaml

# Check status
oc get application ramalama-qwen-4b-dev -n openshift-gitops
oc get pods -l model=qwen3-4b -n ramalama
```

### Option C: Deploy Environment-Specific Configuration

```bash
# For testing with development overlay
oc apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ramalama-dev-environment
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://github.com/kush-gupt/ramalama-k8s.git
    targetRevision: HEAD
    path: k8s/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: ramalama
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

## Step 3: Deploy OpenShift Lightspeed

### Option A: Single Lightspeed Configuration (Recommended)

```bash
# Deploy Lightspeed for specific model
oc apply -f k8s/lightspeed/argocd/application-qwen3-4b.yaml

# Check deployment in openshift-lightspeed namespace
oc get olsconfig,pods,svc -n openshift-lightspeed

# Verify model connectivity
oc get svc -l app.kubernetes.io/name=ramalama -n ramalama
```

### Option B: All Lightspeed Configurations (Expert Only)

> [!WARNING]  
> **Resource Conflicts**: Multiple Lightspeed configurations will conflict over the same `OLSConfig` resource. Use only if you understand ArgoCD resource management.

```bash
# Deploy Lightspeed for all models (creates conflicts)
oc apply -f k8s/lightspeed/argocd/applicationset-lightspeed.yaml

# Monitor Lightspeed deployment and handle conflicts
oc get applications -n openshift-gitops | grep lightspeed
```

## Step 4: Verify Deployment

```bash
# Check all GitOps applications
oc get applications -n openshift-gitops

# Check ramalama models (all in ramalama namespace)
oc get pods,svc -l app.kubernetes.io/name=ramalama -n ramalama

# Check OpenShift Lightspeed
oc get all -n openshift-lightspeed

# Verify service discovery
oc get svc -n ramalama | grep ramalama-service

# Test model API
MODEL_SERVICE=$(oc get svc -n ramalama -l model=qwen3-4b -o jsonpath='{.items[0].metadata.name}')
oc port-forward -n ramalama svc/$MODEL_SERVICE 8080:8080 &
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "default", "messages": [{"role": "user", "content": "Hello!"}]}'
```

## Step 5: Access OpenShift Lightspeed

1. **Open OpenShift Web Console**
2. **Look for the Lightspeed icon** in the navigation
3. **Start asking questions** about your cluster

## Troubleshooting

### Common Issues

**GitOps Applications Not Syncing**
```bash
# Check application status
oc describe application <app-name> -n openshift-gitops

# Force sync if needed
oc patch application <app-name> -n openshift-gitops --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```

**Models Not Starting**
```bash
# Check pod logs
oc logs -n ramalama deployment/<model-name>-ramalama-deployment

# Check events
oc get events -n ramalama --sort-by='.lastTimestamp'

# Check resource constraints
oc describe pod -l model=<model-name> -n ramalama

# Verify image pull
oc get pod -l model=<model-name> -n ramalama -o yaml | grep -A 5 -B 5 image
```

**Service Discovery Issues**
```bash
# Check if services are in the correct namespace
oc get svc -l app.kubernetes.io/name=ramalama -n ramalama

# Test cross-namespace connectivity to Lightspeed
oc exec -n openshift-lightspeed deployment/lightspeed-app-server -- \
  curl -f http://qwen3-4b-ramalama-service.ramalama.svc.cluster.local:8080/v1/models

# Check endpoints
oc get endpoints -n ramalama
```

**Lightspeed Not Working**
```bash
# Check operator status
oc get csv -n openshift-lightspeed | grep lightspeed

# Check OLS configuration and model connectivity
oc get olsconfig cluster -n openshift-lightspeed -o yaml | grep -A 5 -B 5 url

# Verify model service connectivity
oc get svc -n ramalama | grep ramalama-service

# Check Lightspeed logs
oc logs -l app.kubernetes.io/name=lightspeed-app-server -n openshift-lightspeed
```

## Advanced Configuration

### Custom Git Repository

Update the `repoURL` in your ApplicationSet:

```yaml
source:
  repoURL: https://github.com/your-org/your-ramalama-fork.git
  targetRevision: main
  path: k8s/models/qwen3-4b
destination:
  namespace: ramalama
```

### Environment-Specific Configuration

Use overlays for different environments:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ramalama-production-overlay
spec:
  source:
    path: k8s/overlays/production
  destination:
    namespace: ramalama
```

### Private Git Repositories

Add repository credentials to GitOps:

```bash
# Add private repository
oc create secret generic private-repo \
  --from-literal=url=https://github.com/your-org/private-repo.git \
  --from-literal=username=your-username \
  --from-literal=password=your-token \
  -n openshift-gitops

# Label for ArgoCD to recognize
oc label secret private-repo argocd.argoproj.io/secret-type=repository -n openshift-gitops
```

### Multi-Model Deployment Strategy

For anything approaching production environments, consider this:

```yaml
# Deploy models individually to avoid conflicts
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ramalama-qwen3-4b
spec:
  source:
    path: k8s/models/qwen3-4b
  destination:
    namespace: ramalama

---
# Deploy single Lightspeed configuration
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openshift-lightspeed-qwen3-4b
spec:
  source:
    path: k8s/lightspeed/overlays/qwen3-4b
  destination:
    namespace: openshift-lightspeed
```

## Best Practices

1. **Use separate repositories** for configuration and code
2. **Pin image tags** in production environments
3. **Use sync waves** for proper deployment ordering
4. **Monitor sync status** and set up alerts
5. **Test changes** in development environments first
6. **Use proper RBAC** for GitOps applications

## Resources

- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [OpenShift Lightspeed Documentation](https://docs.openshift.com/container-platform/latest/openshift_lightspeed/about-openshift-lightspeed.html) 