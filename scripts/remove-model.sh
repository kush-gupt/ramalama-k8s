#!/bin/bash

# remove-model.sh - Script to remove a model from the ramalama-k8s repository

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
Usage: $0 [OPTIONS] MODEL_NAME

Remove a model from the ramalama-k8s repository.

Arguments:
    MODEL_NAME          Name of the model to remove (e.g., llama-7b, qwen-4b)

Options:
    --dry-run          Show what would be removed without actually removing
    --force            Skip confirmation prompts
    -h, --help         Show this help message

Examples:
    # Remove a model with confirmation
    $0 llama-7b
    
    # Dry run to see what would be removed
    $0 --dry-run llama-7b
    
    # Force removal without confirmation
    $0 --force llama-7b
EOF
}

# Variables
MODEL_NAME=""
DRY_RUN=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$MODEL_NAME" ]]; then
                MODEL_NAME="$1"
            else
                log_error "Too many arguments"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required parameters
if [[ -z "$MODEL_NAME" ]]; then
    log_error "Model name is required"
    show_help
    exit 1
fi

# Sanitize model name
MODEL_NAME_SAFE=$(echo "$MODEL_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')

# Get script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MODELS_YAML="$REPO_ROOT/models/models.yaml"

log_info "Removing model: $MODEL_NAME"
log_info "Sanitized name: $MODEL_NAME_SAFE"

# Find files to remove
FILES_TO_REMOVE=()
DIRS_TO_REMOVE=()
CONTAINERFILE_PATH="$REPO_ROOT/containerfiles/Containerfile-${MODEL_NAME_SAFE}"
MODEL_K8S_DIR="$REPO_ROOT/k8s/models/${MODEL_NAME_SAFE}"
LIGHTSPEED_OVERLAY_DIR="$REPO_ROOT/k8s/lightspeed/overlays/${MODEL_NAME_SAFE}"
CONFIG_PATH="$REPO_ROOT/models/${MODEL_NAME_SAFE}.conf"

if [[ -f "$CONTAINERFILE_PATH" ]]; then
    FILES_TO_REMOVE+=("$CONTAINERFILE_PATH")
fi

if [[ -d "$MODEL_K8S_DIR" ]]; then
    DIRS_TO_REMOVE+=("$MODEL_K8S_DIR")
fi

if [[ -d "$LIGHTSPEED_OVERLAY_DIR" ]]; then
    DIRS_TO_REMOVE+=("$LIGHTSPEED_OVERLAY_DIR")
fi

if [[ -f "$CONFIG_PATH" ]]; then
    FILES_TO_REMOVE+=("$CONFIG_PATH")
fi

# Check if any files exist
if [[ ${#FILES_TO_REMOVE[@]} -eq 0 && ${#DIRS_TO_REMOVE[@]} -eq 0 ]]; then
    log_error "No files or directories found for model: $MODEL_NAME_SAFE"
    exit 1
fi

echo
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY RUN - Files and directories that would be removed:"
else
    log_info "Files and directories to be removed:"
fi

for file in "${FILES_TO_REMOVE[@]}"; do
    echo "  - $(basename "$file")"
done

for dir in "${DIRS_TO_REMOVE[@]}"; do
    echo "  - $(basename "$dir")/ (directory)"
done

# Note: With modular workflow, no workflow entries need to be manually removed
echo "  - NOTE: Modular workflow will automatically exclude this model"

echo

# Confirm removal unless forced or dry run
if [[ "$DRY_RUN" == "false" && "$FORCE" == "false" ]]; then
    read -p "Are you sure you want to remove these files? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Removal cancelled"
        exit 0
    fi
fi

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Dry run completed. No files were actually removed."
    exit 0
fi

# Remove files
for file in "${FILES_TO_REMOVE[@]}"; do
    if [[ -f "$file" ]]; then
        log_info "Removing $(basename "$file")"
        rm "$file"
    fi
done

# Remove directories
for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [[ -d "$dir" ]]; then
        log_info "Removing $(basename "$dir")/ directory"
        rm -rf "$dir"
    fi
done

# Remove from models.yaml if present
if [[ -f "$MODELS_YAML" ]]; then
    # Delete the block under key "  ${MODEL_NAME_SAFE}:" up to the next model key or a top-level key (no indentation)
    tmp_out="$(mktemp)"
    awk -v key="  ${MODEL_NAME_SAFE}:" '
      BEGIN {skip=0}
      {
        if ($0 == key) { skip=1; next }
        if (skip==1 && ($0 ~ /^  [a-z0-9-]+:/ || $0 ~ /^[^ ]/)) { skip=0 }
        if (skip==0) print $0
      }
    ' "$MODELS_YAML" > "$tmp_out" && mv "$tmp_out" "$MODELS_YAML"
    log_info "Removed ${MODEL_NAME_SAFE} from models/models.yaml (if existed)"
fi

# Note: With modular workflow, no manual workflow updates are needed
log_info "Skipping workflow update - using modular workflow system"

log_success "Model $MODEL_NAME removed successfully!"
echo
log_info "The modular workflow will automatically exclude this model from builds"
echo
log_warning "Don't forget to commit and push the changes to update the repository!" 