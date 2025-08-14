#!/bin/bash

# list-models.sh - Script to list all models in the ramalama-k8s repository

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MODELS_YAML="$REPO_ROOT/models/models.yaml"

echo -e "${BLUE}=== Ramalama Models Repository Status ===${NC}"
echo

# List Containerfiles
echo -e "${GREEN}Containerfiles:${NC}"
if ls "$REPO_ROOT/containerfiles"/Containerfile-* >/dev/null 2>&1; then
    for file in "$REPO_ROOT/containerfiles"/Containerfile-*; do
        if [[ "$file" != *"-min" ]]; then
            model_name=$(basename "$file" | sed 's/Containerfile-//')
            echo "  - $model_name"
        fi
    done
else
    echo "  No model containerfiles found"
fi
echo

# List k8s model kustomizations
echo -e "${GREEN}Kubernetes Models (kustomize):${NC}"
if ls "$REPO_ROOT/k8s/models"/*/kustomization.yaml >/dev/null 2>&1; then
    for file in "$REPO_ROOT/k8s/models"/*/kustomization.yaml; do
        model_dir=$(basename "$(dirname "$file")")
        echo "  - $model_dir"
    done
else
    echo "  No model kustomizations found"
fi
echo

# List Lightspeed overlays
echo -e "${GREEN}OpenShift Lightspeed Overlays:${NC}"
if ls "$REPO_ROOT/k8s/lightspeed/overlays"/*/kustomization.yaml >/dev/null 2>&1; then
    for file in "$REPO_ROOT/k8s/lightspeed/overlays"/*/kustomization.yaml; do
        overlay_dir=$(basename "$(dirname "$file")")
        echo "  - $overlay_dir"
    done
else
    echo "  No Lightspeed overlays found"
fi
echo

# List models from models.yaml
echo -e "${GREEN}Models (from models.yaml):${NC}"
if [[ -f "$MODELS_YAML" ]]; then
    # Collect model keys only within the models: section (portable, no mapfile)
    model_keys=$(awk '
      $1=="models:" { in_models=1; next }
      in_models==1 && ($1=="templates:" || $1=="defaults:") { exit }
      in_models==1 && $1 ~ /^[a-z0-9-]+:/ { gsub(":","",$1); print $1 }
    ' "$MODELS_YAML")
    if [[ -n "$model_keys" ]]; then
        for key in $model_keys; do
            echo "  - $key"
            gguf=$(awk -v k="  ${key}:" '
              $0==k { f=1; next }
              f==1 && $0 ~ /^  [a-z0-9-]+:/ { f=0 }
              f==1 && $1=="model_gguf_url:" { $1=""; sub(/^ +/,""); print; exit }
            ' "$MODELS_YAML" | sed -E 's/^"?|"?$//g')
            if [[ -n "$gguf" ]]; then
              echo "    GGUF URL: $gguf"
            fi
        done
    else
        echo "  No models defined in models.yaml"
    fi
else
    echo "  models.yaml not found"
fi
echo

# Check GitHub workflow
echo -e "${GREEN}GitHub Workflow Jobs:${NC}"
if [[ -f "$REPO_ROOT/.github/workflows/build-images.yml" ]]; then
    grep "build-app-image-" "$REPO_ROOT/.github/workflows/build-images.yml" | grep "name:" | sed 's/.*name: Build App Image (/  - /' | sed 's/).*//'
else
    echo "  No GitHub workflow found"
fi
echo

# Summary
containerfile_count=$(find "$REPO_ROOT/containerfiles" -name "Containerfile-*" ! -name "*-min" 2>/dev/null | wc -l)
deployment_count=$(find "$REPO_ROOT/k8s/models" -name "kustomization.yaml" -maxdepth 2 2>/dev/null | wc -l)
lightspeed_overlay_count=$(find "$REPO_ROOT/k8s/lightspeed/overlays" -name "kustomization.yaml" -maxdepth 2 2>/dev/null | wc -l)
config_count=0
if [[ -d "$REPO_ROOT/models" ]]; then
    config_count=$(find "$REPO_ROOT/models" -name "*.conf" 2>/dev/null | wc -l)
fi
models_yaml_count=0
if [[ -f "$MODELS_YAML" ]]; then
    models_yaml_count=$(awk '
      $1=="models:" { in_models=1; next }
      in_models==1 && ($1=="templates:" || $1=="defaults:") { exit }
      in_models==1 && $1 ~ /^[a-z0-9-]+:/ { c++ }
      END { print (c?c:0) }
    ' "$MODELS_YAML")
fi

echo -e "${YELLOW}Summary:${NC}"
echo "  Containerfiles: $containerfile_count"
echo "  Model kustomizations: $deployment_count"
echo "  Lightspeed overlays: $lightspeed_overlay_count"
echo "  .conf configurations: $config_count"
echo "  models.yaml definitions: $models_yaml_count"