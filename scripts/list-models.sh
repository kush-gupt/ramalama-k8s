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

# List k8s deployments
echo -e "${GREEN}Kubernetes Deployments:${NC}"
if ls "$REPO_ROOT/k8s"/deployment-*.yaml >/dev/null 2>&1; then
    for file in "$REPO_ROOT/k8s"/deployment-*.yaml; do
        model_name=$(basename "$file" | sed 's/deployment-//' | sed 's/.yaml//')
        echo "  - $model_name"
    done
else
    echo "  No deployment files found"
fi
echo

# List model configurations
echo -e "${GREEN}Model Configurations:${NC}"
if [[ -d "$REPO_ROOT/models" ]] && ls "$REPO_ROOT/models"/*.conf >/dev/null 2>&1; then
    for file in "$REPO_ROOT/models"/*.conf; do
        model_name=$(basename "$file" | sed 's/.conf//')
        gguf_url=$(grep "MODEL_GGUF_URL" "$file" | cut -d'=' -f2 | tr -d '"')
        echo "  - $model_name"
        if [[ -n "$gguf_url" ]]; then
            echo "    GGUF URL: $gguf_url"
        fi
    done
else
    echo "  No model configuration files found"
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
deployment_count=$(find "$REPO_ROOT/k8s" -name "deployment-*.yaml" 2>/dev/null | wc -l)
config_count=0
if [[ -d "$REPO_ROOT/models" ]]; then
    config_count=$(find "$REPO_ROOT/models" -name "*.conf" 2>/dev/null | wc -l)
fi

echo -e "${YELLOW}Summary:${NC}"
echo "  Containerfiles: $containerfile_count"
echo "  Deployments: $deployment_count"
echo "  Configurations: $config_count" 