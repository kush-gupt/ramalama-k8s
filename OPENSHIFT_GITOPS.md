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

# Monitor deployment
oc get applications -n openshift-gitops -w
```

### Option B: Deploy Single Model

```bash
# Deploy specific model
oc apply -f k8s/argocd/application-example.yaml

# Check status
oc get application ramalama-qwen-4b-dev -n openshift-gitops
```

## Step 3: Deploy OpenShift Lightspeed

### Option A: All Lightspeed Configurations (ApplicationSet)

```bash
# Deploy Lightspeed for all models
oc apply -f k8s/lightspeed/argocd/applicationset-lightspeed.yaml

# Monitor Lightspeed deployment
oc get applications -n openshift-gitops | grep lightspeed
```

### Option B: Single Lightspeed Configuration

```bash
# Deploy Lightspeed for specific model
oc apply -f k8s/lightspeed/argocd/application-qwen3-4b.yaml

# Check deployment
oc get olsconfig,pods,svc -n openshift-lightspeed
```

## Step 4: Verify Deployment

```bash
# Check all GitOps applications
oc get applications -n openshift-gitops

# Check ramalama models
oc get pods,svc -n ramalama

# Check OpenShift Lightspeed
oc get all -n openshift-lightspeed

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
```

**Lightspeed Not Working**
```bash
# Check operator status
oc get csv -n openshift-lightspeed

# Check OLS configuration
oc get olsconfig cluster -n openshift-lightspeed -o yaml

# Check service connectivity
oc get svc -n ramalama | grep ramalama-service
```

## Advanced Configuration

### Custom Git Repository

Update the `repoURL` in your ApplicationSet:

```yaml
source:
  repoURL: https://github.com/your-org/your-ramalama-fork.git
  targetRevision: main
  path: k8s/models/qwen3-4b
```

### Environment-Specific Configuration

Use overlays for different environments:

```yaml
source:
  path: k8s/models/qwen3-4b
  kustomize:
    overlays:
    - '../../../overlays/production'
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