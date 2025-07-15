# Ramalama Kubernetes GitOps Deployment

This directory contains GitOps-compatible Kubernetes manifests for deploying Ramalama LLM models using Kustomize and ArgoCD.

## Important Changes

### Model Path Changes
**Note**: All configurations in this directory now use `/mnt/models/` paths instead of `/models/` for model files. This change provides better alignment with container runtime expectations and default execution behavior. If you have existing deployments, you may need to update your configurations and rebuild your container images.

### Simplified Namespace Structure
**All models now deploy to the `ramalama` namespace** for simplified management and better auto-detection with OpenShift Lightspeed. This consolidates all model services into a single namespace, making service discovery and integration more straightforward.

**Standard Model Path Format**: All model files must be referenced using the format:
```
/mnt/models/Model-Name.gguf/Model-Name.gguf
```

Examples:
- `/mnt/models/Qwen3-1.7B-UD-Q4_K_XL.gguf/Qwen3-1.7B-UD-Q4_K_XL.gguf`
- `/mnt/models/Qwen3-4B-Q4_K_M.gguf/Qwen3-4B-Q4_K_M.gguf`
- `/mnt/models/DeepSeek-R1-0528-Qwen3-8B-UD-Q4_K_XL.gguf/DeepSeek-R1-0528-Qwen3-8B-UD-Q4_K_XL.gguf`

## Directory Structure

```
k8s/
├── base/                          # Base Kustomize resources
│   ├── kustomization.yaml         # Base kustomization configuration
│   ├── service.yaml              # Generic service template
│   ├── configmap.yaml            # Base configuration
│   └── deployment-patch.yaml     # Security and resource patches
├── overlays/                     # Environment-specific overlays
│   ├── dev/                      # Development environment
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   └── resources-patch.yaml
│   └── production/               # Production environment
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       └── resources-patch.yaml
├── models/                       # Model-specific configurations
│   ├── base-model/              # Base model template
│   │   ├── kustomization.yaml
│   │   └── deployment.yaml
│   ├── qwen3-4b/                 # Example model configuration
│   │   └── kustomization.yaml
│   └── [other-models]/
└── argocd/                      # ArgoCD Application examples
    ├── application-example.yaml
    └── applicationset-example.yaml
```

## Features

### GitOps Compatibility
- **Declarative Configuration**: All resources defined as code
- **ArgoCD Sync Waves**: Proper deployment ordering
- **Simplified Namespace Structure**: All models deploy to `ramalama` namespace
- **Automated Deployment**: No manual kubectl required

### Kustomize Structure
- **Base + Overlays**: Reusable base with environment-specific patches
- **ConfigMap Generation**: Dynamic configuration management
- **Image Management**: Centralized image tag management
- **Resource Patching**: Environment-specific resource requests

### Security & Best Practices
- **Pod Security Standards**: Restricted security context
- **Resource Constraints**: Memory and CPU requests
- **Health Checks**: Liveness and readiness probes
- **Non-root Execution**: Secure container runtime

## Quick Start

### 1. Deploy with Kustomize (Direct)

```bash
# Development environment
kubectl apply -k overlays/dev

# Production environment
kubectl apply -k overlays/production
```

### 2. Deploy with ArgoCD

#### Single Model Application
```bash
# Apply the example application
kubectl apply -f argocd/application-example.yaml
```

#### Multiple Models with ApplicationSet
```bash
# Deploy all models across all environments
kubectl apply -f argocd/applicationset-example.yaml
```

## Model Management

### Adding a New Model

Use the model management scripts with the new GitOps structure:

```bash
# Interactive mode
./scripts/add-model.sh --interactive

# Command line mode
./scripts/add-model.sh \
  --name "llama-7b" \
  --description "Llama 7B Chat model" \
  --model-source "quay.io/user/llama-7b:latest" \
  --model-file "/mnt/models/llama-7b.gguf/llama-7b.gguf"
```

This creates:
- `k8s/models/llama-7b/kustomization.yaml`
- Containerfile and configuration files
- Automatic ArgoCD discovery (with ApplicationSet)

### Configuration Management

Models use a layered configuration approach:

1. **Base Configuration** (`base/configmap.yaml`): Common settings
2. **Environment Overlays** (`overlays/*/`): Environment-specific settings  
3. **Model-Specific** (`models/*/kustomization.yaml`): Model parameters

Example model configuration:
```yaml
configMapGenerator:
- name: model-config
  literals:
  - MODEL_NAME=Llama 7B
  - MODEL_FILE=/mnt/models/llama-7b.gguf
  - ALIAS=llama-7b-model
- name: ramalama-config
  behavior: merge
  literals:
  - CTX_SIZE=8192
  - THREADS=16
  - TEMP=0.7
```

## Environment Configuration

### Development (`overlays/dev/`)
- Lower resource requests
- Single replica
- Debug logging enabled
- Relaxed security policies

### Production (`overlays/production/`)
- Higher resource requests
- Single replica (configurable)
- Restricted security context
- Pod security standards enforced
- Stable image tags

## ArgoCD Integration

### Application Pattern
For deploying a single model to a specific environment:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ramalama-qwen3-4b-prod
spec:
  source:
    path: k8s/models/qwen3-4b
    kustomize:
      overlays:
      - ../../../overlays/production
  destination:
    namespace: ramalama-production
```

### ApplicationSet Pattern
For managing multiple models across environments automatically:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: ramalama-models
spec:
  generators:
  - matrix:
      generators:
      - git:
          directories:
          - path: k8s/models/*
      - list:
          elements:
          - env: dev
          - env: production
```

## Monitoring & Observability

### Health Checks
- Liveness probe: `/health`
- Readiness probe: `/health`
- Configurable timeouts and thresholds

### Resource Monitoring
- CPU and memory requests defined
- Resource usage can be monitored via Kubernetes metrics
- Configurable resource constraints per environment

## Security

### Pod Security
- Non-root user execution
- Dropped capabilities (ALL)
- Security context constraints
- Privilege escalation disabled

### Runtime Security
- Seccomp profiles applied
- Pod security standards enforced
- Minimal attack surface
- Container isolation

## Troubleshooting

### Common Issues

1. **Image Pull Errors**
   ```bash
   # Check image configuration
   kubectl get kustomization -o yaml | grep image
   ```

2. **Configuration Issues**
   ```bash
   # Verify ConfigMap generation
   kubectl get configmap -l app.kubernetes.io/name=ramalama
   ```

3. **ArgoCD Sync Issues**
   ```bash
   # Check application status
argocd app get ramalama-qwen3-4b-dev
```

### Debugging Commands

```bash
# Test kustomization locally
kustomize build k8s/models/qwen3-4b

# Apply with overlays
kustomize build k8s/overlays/dev | kubectl apply -f -

# Check generated resources
kubectl get all -l app.kubernetes.io/name=ramalama
```

## Migration from Legacy Deployments

If migrating from the old deployment structure:

1. **Backup existing deployments**
2. **Generate new kustomizations** using updated scripts
3. **Test in dev environment** first
4. **Update ArgoCD applications** to use new paths
5. **Remove old deployment files**

The migration scripts handle this automatically when regenerating configurations.

## Best Practices

1. **Use environment overlays** for environment-specific configurations
2. **Leverage ConfigMap generators** for dynamic configuration
3. **Implement proper sync waves** for ordered deployment
4. **Use ApplicationSets** for managing multiple models
5. **Monitor resource usage** and adjust requests accordingly
6. **Test changes in dev** before promoting to production

## Contributing

When adding new features:
1. Update base templates if needed
2. Test with multiple environments
3. Update documentation
4. Ensure ArgoCD compatibility
5. Add proper labels and annotations 