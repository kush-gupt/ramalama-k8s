# Ramalama Kubernetes GitOps Deployment

This directory contains GitOps-compatible Kubernetes manifests for deploying Ramalama LLM models using Kustomize and ArgoCD.

## Important Changes

### Simplified Namespace Structure
**All models deploy to the `ramalama` namespace** for simplified management and better auto-detection with OpenShift Lightspeed. This consolidates all model services into a single namespace, making service discovery and integration more straightforward.

**Why a Single Namespace?**
- **🔗 Service Discovery**: Simplified networking between models and Lightspeed
- **🛡️ Security**: Easier RBAC and network policy management
- **🔧 Management**: Single point of configuration and monitoring
- **🚫 Conflict Prevention**: Avoids namespace prefix conflicts from Kustomize

**Standard Model Path Format**: All model files must be referenced using the format:
```
/models/Model-Name.gguf/Model-Name.gguf
```

Examples:
- `/models/Qwen3-1.7B-UD-Q4_K_XL.gguf/Qwen3-1.7B-UD-Q4_K_XL.gguf`
- `/models/Qwen3-4B-Q4_K_M.gguf/Qwen3-4B-Q4_K_M.gguf`
- `/models/DeepSeek-R1-0528-Qwen3-8B-UD-Q4_K_XL.gguf/DeepSeek-R1-0528-Qwen3-8B-UD-Q4_K_XL.gguf`

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
│   ├── ramalama-namespace.yaml  # Shared namespace definition
│   ├── base-model/              # Base model template
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── deployment-patch.yaml
│   ├── qwen3-4b/                 # Example model configuration
│   │   ├── kustomization.yaml
│   │   └── model-patch.yaml
│   └── [other-models]/
└── argocd/                      # ArgoCD Application examples
    ├── application-example.yaml
    └── applicationset-example.yaml
```
## Quick Start

### 1. Deploy with Kustomize (Direct)

#### Single Model Deployment
```bash
# Create the shared namespace first
kubectl create namespace ramalama

# Deploy a specific model
kubectl apply -k k8s/models/qwen3-4b

# Check deployment
kubectl get all -l model=qwen3-4b -n ramalama
```

### 2. Deploy with ArgoCD

#### Single Model Application
```bash
# Apply the example application
kubectl apply -f k8s/argocd/application-example.yaml
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
  --model-file "/models/llama-7b.gguf/llama-7b.gguf"
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
  - MODEL_FILE=/models/llama-7b.gguf
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
- Includes base model deployment for standalone testing
- Lower resource requests (1Gi memory, 250m CPU)
- Single replica
- Debug logging enabled
- Relaxed security policies

### Production (`overlays/production/`)
- Includes base model deployment for standalone testing  
- Higher resource requests (8Gi memory, 4 CPU)
- Single replica (configurable)
- Restricted security context
- Pod security standards enforced
- Stable image tags

> [!NOTE]  
> **Overlay Usage**: Environment overlays are designed for standalone testing and development. For production GitOps, use model-specific deployments with ArgoCD Applications.

## OpenShift GitOps Integration

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
  destination:
    namespace: ramalama
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

### Debugging Commands

```bash
# Test kustomization locally
kustomize build k8s/models/qwen3-4b

# Test with overlays
kustomize build k8s/overlays/dev

# Check generated resources
oc get all -l app.kubernetes.io/name=ramalama -n ramalama

# View logs
oc logs -l model=qwen3-4b -n ramalama --tail=100
```

## Best Practices

1. **Use the shared namespace** - All models should deploy to `ramalama`
2. **Use environment overlays** for development and testing only
3. **Leverage ConfigMap generators** for dynamic configuration
4. **Implement proper sync waves** for ordered deployment
5. **Use ApplicationSets** for managing multiple models
6. **Monitor resource usage** and adjust requests accordingly
7. **Test changes in dev** before promoting to production
8. **Use model-specific deployments** for production GitOps

## Contributing

When adding new features:
1. Update base templates if needed
2. Test with multiple environments
3. Update documentation
4. Ensure OpenShift GitOps compatibility
5. Add proper labels and annotations
6. Test namespace consistency

## Namespace Architecture

```mermaid
graph TB
    subgraph "ramalama namespace"
        M1[qwen3-1b-ramalama-deployment]
        M2[qwen3-4b-ramalama-deployment]
        M3[qwen3-30b-ramalama-deployment]
        M4[deepseek-r1-qwen3-8b-ramalama-deployment]
        S1[qwen3-1b-ramalama-service]
        S2[qwen3-4b-ramalama-service]
        S3[qwen3-30b-ramalama-service]
        S4[deepseek-r1-qwen3-8b-ramalama-service]
    end
    
    subgraph "openshift-lightspeed namespace"
        LS[OpenShift Lightspeed]
    end
    
    LS -.-> S1
    LS -.-> S2
    LS -.-> S3
    LS -.-> S4
    
    style M1 fill:#e1f5fe
    style M2 fill:#e1f5fe  
    style M3 fill:#e1f5fe
    style M4 fill:#e1f5fe
    style LS fill:#f3e5f5
```

This simplified architecture ensures consistent service discovery and easier management across all components. 