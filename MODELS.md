# Model Management System

This document describes the enhanced model management system for the ramalama-k8s repository, which provides tools to easily add, manage, and remove models.

## Overview

The model management system consists of several components:

1. **Configuration-based approach** using `models/models.yaml`
2. **Scripts for model lifecycle management**
3. **Template system for consistency**
4. **Automated generation of all required files**

## Important Path Changes

**Note**: This repository now uses `/mnt/models/` paths instead of `/models/` for all model files. This change provides better alignment with container runtime expectations and default execution behavior.

### What Changed

- **Default model file paths**: All examples and defaults now use `/mnt/models/`
- **Container images**: Models are copied to `/mnt/models/` inside containers
- **Configuration files**: All `.conf` files and `models.yaml` use `/mnt/models/` paths
- **Kubernetes deployments**: All k8s configurations reference `/mnt/models/` paths

### Migration

If you have existing configurations:

1. **Update model file paths** in your configurations to use `/mnt/models/` instead of `/models/`
2. **Update deployment commands** to use the shared namespace approach
3. **Rebuild container images** with the updated Containerfiles

The CLI parameters still accept any path you specify, so you can override the defaults if needed.

## Quick Start

### Adding a New Model (Interactive)

```bash
# Interactive mode - prompts for all required information
./scripts/add-model.sh --interactive
```

### Adding a New Model (Command Line)

```bash
./scripts/add-model.sh \
  --name "llama-7b" \
  --description "Llama 7B Chat model" \
  --model-source "quay.io/user/llama-7b:latest" \
  --model-file "/mnt/models/llama-7b.gguf/llama-7b.gguf" \
  --ctx-size 4096 \
  --temp 0.7
```

### Deploying Models

#### Single Model Deployment

```bash
# Create the shared namespace first (if it doesn't exist)
kubectl apply -f k8s/models/ramalama-namespace.yaml

# Deploy the model (automatically goes to ramalama namespace)
kubectl apply -k k8s/models/llama-7b

# Check deployment
kubectl get all -l model=llama-7b -n ramalama
```

#### Environment-Specific Testing

```bash
# Development environment (includes namespace creation and base model)
kubectl apply -k k8s/overlays/dev

# Production environment (includes namespace creation and base model)
kubectl apply -k k8s/overlays/production

# Check deployment
kubectl get pods -n ramalama
```

### Listing All Models

```bash
./scripts/list-models.sh
```

### Removing a Model

```bash
# With confirmation
./scripts/remove-model.sh llama-7b

# Dry run to see what would be removed
./scripts/remove-model.sh --dry-run llama-7b

# Force removal without confirmation
./scripts/remove-model.sh --force llama-7b
```

### Configuration-Based Management

```bash
# Generate all files from YAML configuration
./scripts/generate-from-config.py

# Use custom config file
./scripts/generate-from-config.py --config custom-models.yaml
```

## Configuration File Structure

The main configuration file is `models/models.yaml`. Here's the structure:

```yaml
models:
  model-key:
    name: "Human Readable Name"
    description: "Model description for labels"
    model_source: "registry/image:tag"
    model_file: "/mnt/models/path/to/model.gguf"
    maintainer: "Maintainer Name"
    template: "llama"  # Optional: use predefined template
    resource_size: "medium"  # small/medium/large for template resources
    create_lightspeed_overlay: true  # Generate OpenShift Lightspeed integration
    parameters:
      ctx_size: 4096
      threads: 14
      temp: 0.7
      top_k: 40
      top_p: 0.9
      cache_reuse: 256
    resources:
      requests:
        memory: "4Gi"
        cpu: "2"
      limits:
        memory: "8Gi"
        cpu: "4"

templates:
  llama:
    parameters:
      ctx_size: 4096
      temp: 0.7
      # ... other defaults
    resources:
      small:
        requests:
          memory: "4Gi"
          cpu: "2"
      medium:
        requests:
          memory: "8Gi"
          cpu: "4"

defaults:
  maintainer: "Default Maintainer"
  lightspeed_namespace: "ramalama"  # Namespace where models are deployed
  parameters:
    ctx_size: 4096
    threads: 14
    # ... other defaults
```

## Generated Files

When you add a model, the following files are automatically generated:

### 1. Containerfile
- **Location**: `containerfiles/Containerfile-{model-name}`
- **Purpose**: Defines how to build the container image
- **Template**: Uses base image and copies model from source

### 2. Kubernetes Kustomization
- **Location**: `k8s/models/{model-name}/kustomization.yaml`
- **Purpose**: GitOps-compatible Kubernetes configuration
- **Features**: Environment overlays, ConfigMap generation, security context
- **Namespace**: All models deploy to `ramalama` namespace

### 3. OpenShift Lightspeed Integration (Optional)
- **Location**: `k8s/lightspeed/overlays/{model-name}/kustomization.yaml`
- **Purpose**: Automatic AI assistant integration
- **Features**: Service discovery, configuration management

### 4. GitHub Workflow Integration
- **Location**: Updates `.github/workflows/build-images.yml`
- **Purpose**: Adds CI/CD job for the new model
- **Features**: Automatic building and pushing to registry

### 5. Model Configuration
- **Location**: `models/{model-name}.conf`
- **Purpose**: Shell-compatible configuration file
- **Usage**: Can be sourced by scripts for automation

## Templates

Templates provide default configurations for common model families:

### Available Templates

- **llama**: Optimized for Llama family models
- **mistral**: Optimized for Mistral family models

### Using Templates

```yaml
models:
  my-llama-model:
    name: "My Llama Model"
    template: "llama"
    resource_size: "medium"  # Uses medium resources from llama template
    # Other specific configurations override template defaults
```

## Scripts Reference

### add-model.sh

Adds a new model to the repository.

**Options:**
- `-n, --name`: Model name (required)
- `-d, --description`: Model description (required)
- `-m, --model-source`: Model source image (required)
- `-f, --model-file`: Model file path in container (required)
- `-c, --config`: Use config file
- `--ctx-size`: Context size (default: 20048)
- `--threads`: Number of threads (default: 14)
- `--temp`: Temperature (default: 0.6)
- `--top-k`: Top-k value (default: 20)
- `--top-p`: Top-p value (default: 0.95)
- `--cache-reuse`: Cache reuse value (default: 256)
- `--maintainer`: Maintainer name
- `--create-lightspeed-overlay`: Create OpenShift Lightspeed integration
- `--lightspeed-namespace`: Namespace for ramalama services (default: ramalama)
- `--interactive`: Interactive mode
- `-h, --help`: Show help

**Examples:**
```bash
# Interactive mode
./scripts/add-model.sh --interactive

# Command line with all options including Lightspeed
./scripts/add-model.sh \
  --name "mistral-7b" \
  --description "Mistral 7B Instruct model" \
  --model-source "quay.io/user/mistral-7b:latest" \
  --model-file "/mnt/models/mistral-7b.gguf/mistral-7b.gguf" \
  --ctx-size 8192 \
  --temp 0.6 \
  --maintainer "Your Name" \
  --create-lightspeed-overlay

# Using a config file
./scripts/add-model.sh --config models/mistral-7b.conf
```

### list-models.sh

Lists all models currently in the repository.

**Output includes:**
- Containerfiles
- Kubernetes deployments
- Model configurations
- GitHub workflow jobs
- Summary statistics

### remove-model.sh

Removes a model from the repository.

**Options:**
- `--dry-run`: Show what would be removed without removing
- `--force`: Skip confirmation prompts
- `-h, --help`: Show help

**What it removes:**
- Containerfile
- Kubernetes deployment
- Model configuration
- OpenShift Lightspeed overlay (if exists)
- GitHub workflow job and environment variable

### generate-from-config.py

Generates all model files from the YAML configuration.

**Options:**
- `--config, -c`: Path to YAML config file (default: models/models.yaml)
- `--repo-root, -r`: Repository root path (default: .)

**Features:**
- Template inheritance
- Default value merging
- Automatic file generation
- Workflow integration
- OpenShift Lightspeed overlay generation

## Best Practices

### 1. Model Naming

- Use lowercase with hyphens: `llama-7b`, `mistral-instruct`
- Include size indication: `7b`, `13b`, `30b`
- Be descriptive but concise

### 2. Namespace Management

- **Always use the shared `ramalama` namespace** for model deployments
- **Create namespace before deployment**: `oc apply -f k8s/models/ramalama-namespace.yaml`
- **Verify namespace exists**: `oc get namespace ramalama`
- **Check service discovery**: `oc get svc -n ramalama -l app.kubernetes.io/name=ramalama`

### 3. Resource Allocation

**Small models (<7B parameters):**
```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "2"
```

**Medium models (7B-13B parameters):**
```yaml
resources:
  requests:
    memory: "8Gi"
    cpu: "4"
```

**Large models (>13B parameters):**
```yaml
resources:
  requests:
    memory: "16Gi"
    cpu: "6"
```

### 4. Parameter Tuning

**For chat/instruct models:**
- Higher temperature (0.7-0.9)
- Lower top-k (20-40)
- Higher context size (4096-8192)

**for code generation:**
- Lower temperature (0.1-0.3)
- Higher top-k (40-80)
- Larger context size (8192+)

### 5. Testing

Before committing:
1. **Verify namespace**: `oc get namespace ramalama`
2. **Test local build**: `podman build -f containerfiles/Containerfile-{model} .`
3. **Test deployment**: `oc apply -k k8s/models/{model}`
4. **Check service discovery**: `oc get svc -l model={model} -n ramalama`
5. **Verify workflow syntax**: Check GitHub Actions tab after push

## Troubleshooting

### Common Issues

**1. Namespace Creation Problems**
```bash
# Ensure the ramalama namespace exists
oc apply -f k8s/models/ramalama-namespace.yaml

# Or create manually
oc create project ramalama

# Check if namespace exists
oc get project ramalama
```

**2. Service Discovery Issues**
```bash
# Check if services are in the correct namespace
oc get svc -l app.kubernetes.io/name=ramalama -n ramalama

# Test service connectivity
oc port-forward -n ramalama svc/{model-name}-ramalama-service 8080:8080

# Check endpoints
oc get endpoints -n ramalama
```

**3. Model file path incorrect**
- Verify the path exists in the model source image
- Check exact capitalization and path structure
- Ensure using `/mnt/models/` prefix

**4. Resource constraints**
- Adjust memory/CPU requests based on model size
- Monitor actual usage and adjust limits accordingly
- Check pod status: `oc describe pod -l model={model-name} -n ramalama`

**5. Build failures**
- Ensure model source image is accessible
- Verify base image compatibility
- Check build logs in GitHub Actions

**6. Workflow errors**
- Check GitHub Actions logs for specific errors
- Verify registry permissions and secrets

### Debugging Commands

```bash
# Check what files exist for a model
ls -la containerfiles/Containerfile-{model-name}
ls -la k8s/models/{model-name}/kustomization.yaml
ls -la models/{model-name}.conf

# Verify workflow syntax
grep -A 20 "build-app-image-{model-name}" .github/workflows/build-images.yml

# Test local build
export BASE_IMAGE_TAG="your-registry/centos-ramalama-min:latest"
podman build -f containerfiles/Containerfile-{model-name} \
  --build-arg BASE_IMAGE_NAME="$BASE_IMAGE_TAG" \
  --build-arg MODEL_SOURCE_NAME="model-source-image" \
  -t test-image .
```

## Migration from Manual Process

If you have existing manually created files:

1. **Backup existing files**:
   ```bash
   cp -r containerfiles containerfiles.backup
   cp -r k8s k8s.backup
   cp .github/workflows/build-images.yml .github/workflows/build-images.yml.backup
   ```

2. **Create YAML configuration** for existing models in `models/models.yaml`

3. **Generate new files**:
   ```bash
   ./scripts/generate-from-config.py
   ```

   This will create the new GitOps-compatible structure under `k8s/models/`

4. **Compare and verify** the generated files match your requirements

5. **Test the build process** before committing

## Contributing

When adding new features to the model management system:

1. Update templates in `scripts/templates/` if needed
2. Modify the generator scripts to support new features
3. Update this documentation
4. Test with multiple model types
5. Add examples to the configuration file

## Support

For issues with the model management system:

1. Check this documentation first
2. Review existing model configurations for examples
3. Test with dry-run options before making changes
4. Create GitHub issues for bugs or feature requests 