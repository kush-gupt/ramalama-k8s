#!/bin/bash

# add-model.sh - Script to add a new model to the ramalama-k8s repository
# This script generates Containerfile, k8s deployment, and updates GitHub workflow

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Add a new model to the ramalama-k8s repository.

Options:
    -n, --name           Model name (e.g., llama-7b, mistral-7b)
    -d, --description    Model description
    -u, --model-gguf-url Model GGUF URL (e.g., hf://...)
    -f, --model-file     Model file path inside container (e.g., /models/model.gguf/model.gguf)
    -s, --model-source   Model source image basename (optional, defaults to MODEL_NAME-source)
    -c, --config         Use config file (optional)
    --registry-path     Container registry path for images (default: ghcr.io/kush-gupt)
    --ctx-size          Context size (default: 20048)
    --threads           Number of threads (default: 14)
    --temp              Temperature (default: 0.6)
    --top-k             Top-k value (default: 20)
    --top-p             Top-p value (default: 0.95)
    --cache-reuse       Cache reuse value (default: 256)
    --maintainer        Maintainer name (default: "Kush Gupta")
    --interactive       Interactive mode to prompt for values
    -h, --help          Show this help message

Examples:
    # Interactive mode
    $0 --interactive
    
    # Command line mode
    $0 --name llama-7b \\
       --description "Llama 7B model" \\
       --model-gguf-url "hf://ggml-org/llama-7b/llama-7b.gguf" \\
       --model-file "/models/llama-7b.gguf/llama-7b.gguf"
    
    # Using config file
    $0 --config models/llama-7b.conf
EOF
}

# Default values
DEFAULT_CTX_SIZE=20048
DEFAULT_THREADS=14
DEFAULT_TEMP=0.6
DEFAULT_TOP_K=20
DEFAULT_TOP_P=0.95
DEFAULT_CACHE_REUSE=256
DEFAULT_MAINTAINER="Kush Gupta"
DEFAULT_REGISTRY_PATH="ghcr.io/kush-gupt"

# Variables
MODEL_NAME=""
MODEL_DESCRIPTION=""
MODEL_GGUF_URL=""
MODEL_SOURCE=""
MODEL_FILE=""
CTX_SIZE=$DEFAULT_CTX_SIZE
THREADS=$DEFAULT_THREADS
TEMP=$DEFAULT_TEMP
TOP_K=$DEFAULT_TOP_K
TOP_P=$DEFAULT_TOP_P
CACHE_REUSE=$DEFAULT_CACHE_REUSE
MAINTAINER="$DEFAULT_MAINTAINER"
REGISTRY_PATH="$DEFAULT_REGISTRY_PATH"
CONFIG_FILE=""
INTERACTIVE_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            MODEL_NAME="$2"
            shift 2
            ;;
        -d|--description)
            MODEL_DESCRIPTION="$2"
            shift 2
            ;;
        -u|--model-gguf-url)
            MODEL_GGUF_URL="$2"
            shift 2
            ;;
        -f|--model-file)
            MODEL_FILE="$2"
            shift 2
            ;;
        -s|--model-source)
            MODEL_SOURCE="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --registry-path)
            REGISTRY_PATH="$2"
            shift 2
            ;;
        --ctx-size)
            CTX_SIZE="$2"
            shift 2
            ;;
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --temp)
            TEMP="$2"
            shift 2
            ;;
        --top-k)
            TOP_K="$2"
            shift 2
            ;;
        --top-p)
            TOP_P="$2"
            shift 2
            ;;
        --cache-reuse)
            CACHE_REUSE="$2"
            shift 2
            ;;
        --maintainer)
            MAINTAINER="$2"
            shift 2
            ;;
        --interactive)
            INTERACTIVE_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Load config file if specified
if [[ -n "$CONFIG_FILE" ]]; then
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from $CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    else
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi
fi

# Interactive mode
if [[ "$INTERACTIVE_MODE" == "true" ]]; then
    echo -e "${BLUE}=== Interactive Model Addition ===${NC}"
    echo
    
    read -p "Model name (e.g., llama-7b): " MODEL_NAME
    read -p "Model description: " MODEL_DESCRIPTION
    read -p "Model GGUF URL (e.g., hf://...): " MODEL_GGUF_URL
    read -p "Model file path inside container: " MODEL_FILE
    read -p "Model source image basename (optional, defaults to <model-name>-source): " MODEL_SOURCE
    read -p "Context size [$DEFAULT_CTX_SIZE]: " CTX_SIZE
    read -p "Number of threads [$DEFAULT_THREADS]: " THREADS
    read -p "Temperature [$DEFAULT_TEMP]: " TEMP
    read -p "Top-k [$DEFAULT_TOP_K]: " TOP_K
    read -p "Top-p [$DEFAULT_TOP_P]: " TOP_P
    read -p "Cache reuse [$DEFAULT_CACHE_REUSE]: " CACHE_REUSE
    read -p "Maintainer [$DEFAULT_MAINTAINER]: " MAINTAINER
    read -p "Registry Path [$DEFAULT_REGISTRY_PATH]: " REGISTRY_PATH
    
    # Use defaults if empty
    CTX_SIZE=${CTX_SIZE:-$DEFAULT_CTX_SIZE}
    THREADS=${THREADS:-$DEFAULT_THREADS}
    TEMP=${TEMP:-$DEFAULT_TEMP}
    TOP_K=${TOP_K:-$DEFAULT_TOP_K}
    TOP_P=${TOP_P:-$DEFAULT_TOP_P}
    CACHE_REUSE=${CACHE_REUSE:-$DEFAULT_CACHE_REUSE}
    MAINTAINER=${MAINTAINER:-$DEFAULT_MAINTAINER}
    REGISTRY_PATH=${REGISTRY_PATH:-$DEFAULT_REGISTRY_PATH}
fi

# Validate required parameters
if [[ -z "$MODEL_NAME" ]]; then
    log_error "Model name is required"
    exit 1
fi

if [[ -z "$MODEL_DESCRIPTION" ]]; then
    log_error "Model description is required"
    exit 1
fi

if [[ -z "$MODEL_GGUF_URL" ]]; then
    log_error "Model GGUF URL is required"
    exit 1
fi

if [[ -z "$MODEL_FILE" ]]; then
    log_error "Model file path is required"
    exit 1
fi

# Sanitize model name for file names
MODEL_NAME_SAFE=$(echo "$MODEL_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')

# Set model source if not provided
if [[ -z "$MODEL_SOURCE" ]]; then
    MODEL_SOURCE="${MODEL_NAME_SAFE}-source"
fi

log_info "Adding model: $MODEL_NAME"
log_info "Sanitized name: $MODEL_NAME_SAFE"

# Get script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Create templates directory if it doesn't exist
mkdir -p "$TEMPLATES_DIR"

# Function to create Containerfile template if it doesn't exist
create_containerfile_template() {
    local template_file="$TEMPLATES_DIR/Containerfile.template"
    if [[ ! -f "$template_file" ]]; then
        log_info "Creating Containerfile template"
        cat > "$template_file" << 'EOF'
ARG BASE_IMAGE_NAME
ARG MODEL_SOURCE_NAME
FROM ${BASE_IMAGE_NAME}

ARG MODEL_SOURCE_NAME

# Copy the entire /models directory from the model source
# into the final application image.
COPY --from=${MODEL_SOURCE_NAME} /models /models

# This is a sanity check for OpenShift's random user ID.
USER root
RUN chmod -R a+rX /models
USER 1001

# Optional: Add labels to describe your new all-in-one image
LABEL maintainer="{{MAINTAINER}}"
LABEL description="{{DESCRIPTION}}"
EOF
    fi
}

# Function to create k8s deployment template if it doesn't exist
create_k8s_template() {
    local template_file="$TEMPLATES_DIR/deployment.template.yaml"
    if [[ ! -f "$template_file" ]]; then
        log_info "Creating k8s deployment template"
        cat > "$template_file" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ramalama-{{MODEL_NAME_SAFE}}
  labels:
    app: ramalama-{{MODEL_NAME_SAFE}}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ramalama-{{MODEL_NAME_SAFE}}
  template:
    metadata:
      labels:
        app: ramalama-{{MODEL_NAME_SAFE}}
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: "RuntimeDefault"
      containers:
      - name: ramalama-{{MODEL_NAME_SAFE}}
        image: {{APP_IMAGE_URL}}
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - "ALL"
        command: ["/usr/libexec/ramalama/ramalama-serve-core"]
        args:
        - 'llama-server'
        - '--port'
        - '8080'
        - '--model'
        - '{{MODEL_FILE}}'
        - '--no-warmup'
        - '--jinja'
        - '--log-colors'
        - '--alias'
        - '{{MODEL_NAME_SAFE}}-model'
        - '--ctx-size'
        - '{{CTX_SIZE}}'
        - '--temp'
        - '{{TEMP}}'
        - '--cache-reuse'
        - '{{CACHE_REUSE}}'
        - '-ngl'
        - '-1'
        - '--threads'
        - '{{THREADS}}'
        - '--top-k'
        - '{{TOP_K}}'
        - '--top-p'
        - '{{TOP_P}}'
        - '--min-p'
        - '0'
        - '--host'
        - '0.0.0.0'
        ports:
        - containerPort: 8080
EOF
    fi
}

# Function to substitute template variables
substitute_template() {
    local template_file="$1"
    local output_file="$2"
    local app_image_url="${REGISTRY_PATH}/${MODEL_NAME_SAFE}-ramalama:latest"
    
    sed -e "s|{{MODEL_NAME}}|$MODEL_NAME|g" \
        -e "s|{{MODEL_NAME_SAFE}}|$MODEL_NAME_SAFE|g" \
        -e "s|{{DESCRIPTION}}|$MODEL_DESCRIPTION|g" \
        -e "s|{{MODEL_GGUF_URL}}|${MODEL_GGUF_URL}|g" \
        -e "s|{{MODEL_SOURCE}}|$MODEL_SOURCE|g" \
        -e "s|{{MODEL_FILE}}|$MODEL_FILE|g" \
        -e "s|{{APP_IMAGE_URL}}|${app_image_url}|g" \
        -e "s|{{CTX_SIZE}}|$CTX_SIZE|g" \
        -e "s|{{THREADS}}|$THREADS|g" \
        -e "s|{{TEMP}}|$TEMP|g" \
        -e "s|{{TOP_K}}|$TOP_K|g" \
        -e "s|{{TOP_P}}|$TOP_P|g" \
        -e "s|{{CACHE_REUSE}}|$CACHE_REUSE|g" \
        -e "s|{{MAINTAINER}}|$MAINTAINER|g" \
        "$template_file" > "$output_file"
}

# Create templates
create_containerfile_template
create_k8s_template

# Generate Containerfile
log_info "Generating Containerfile-${MODEL_NAME_SAFE}"
CONTAINERFILE_PATH="$REPO_ROOT/containerfiles/Containerfile-${MODEL_NAME_SAFE}"
substitute_template "$TEMPLATES_DIR/Containerfile.template" "$CONTAINERFILE_PATH"

# Generate k8s deployment
log_info "Generating deployment-${MODEL_NAME_SAFE}.yaml"
DEPLOYMENT_PATH="$REPO_ROOT/k8s/deployment-${MODEL_NAME_SAFE}.yaml"
substitute_template "$TEMPLATES_DIR/deployment.template.yaml" "$DEPLOYMENT_PATH"

# Note: With the new modular workflow system, no manual workflow updates are needed!
# The workflow automatically discovers models from the models.yaml configuration file.
log_info "Skipping workflow update - using modular workflow system"

# Create model configuration file for future reference
log_info "Creating model configuration file"
CONFIG_DIR="$REPO_ROOT/models"
mkdir -p "$CONFIG_DIR"
CONFIG_FILE_PATH="$CONFIG_DIR/${MODEL_NAME_SAFE}.conf"

cat > "$CONFIG_FILE_PATH" << EOF
# Configuration for ${MODEL_NAME}
MODEL_NAME="$MODEL_NAME"
MODEL_DESCRIPTION="$MODEL_DESCRIPTION"
MODEL_GGUF_URL="$MODEL_GGUF_URL"
MODEL_SOURCE="$MODEL_SOURCE"
MODEL_FILE="$MODEL_FILE"
CTX_SIZE=$CTX_SIZE
THREADS=$THREADS
TEMP=$TEMP
TOP_K=$TOP_K
TOP_P=$TOP_P
CACHE_REUSE=$CACHE_REUSE
MAINTAINER="$MAINTAINER"
EOF

# Summary
echo
log_success "Model $MODEL_NAME added successfully!"
echo
echo -e "${BLUE}Generated files:${NC}"
echo "  - containerfiles/Containerfile-${MODEL_NAME_SAFE}"
echo "  - k8s/deployment-${MODEL_NAME_SAFE}.yaml"
echo "  - models/${MODEL_NAME_SAFE}.conf"
echo "  - NOTE: Workflow is automatically updated via modular system!"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review the generated files"
echo "2. Build and push the source image:"
echo -e "${YELLOW}ramalama convert ${MODEL_GGUF_URL} oci://${REGISTRY_PATH}/${MODEL_SOURCE}:latest${NC}"
echo "3. Commit and push to trigger the CI/CD pipeline (uses modular workflow)"
echo "4. Build and test locally if needed:"
echo
echo -e "${YELLOW}Local build example:${NC}"
export IMAGE_OWNER="your-registry/username"
export BASE_IMAGE_TAG="\${IMAGE_OWNER}/centos-ramalama-min:latest"
export APP_IMAGE_TAG="\${IMAGE_OWNER}/${MODEL_NAME_SAFE}-ramalama:latest"
export MODEL_SOURCE_IMAGE="${REGISTRY_PATH}/${MODEL_SOURCE}:latest"

podman build \\
  -f containerfiles/Containerfile-${MODEL_NAME_SAFE} \\
  --build-arg BASE_IMAGE_NAME="\${BASE_IMAGE_TAG}" \\
  --build-arg MODEL_SOURCE_NAME="\${MODEL_SOURCE_IMAGE}" \\
  -t "\${APP_IMAGE_TAG}" \\
  .

log_info "The modular workflow will automatically discover and build this model from models.yaml" 