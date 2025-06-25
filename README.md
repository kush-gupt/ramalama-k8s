# Ramalama Container Images

This repository contains the necessary files to build container images for the Ramalama project, a server environment for running language models using `llama.cpp`.

The images are designed to be built using Podman and include a base image with dependencies and application images with specific models.

## Repository Structure

The repository is organized as follows:

```
.
├── .github/workflows/        # GitHub Actions CI workflows
│   └── build-images.yml      # CI pipeline for building and pushing images
├── containerfiles/           # Containerfile definitions
│   ├── Containerfile         # Builds the Qwen-4B application image
│   ├── Containerfile-min     # Builds the base centos-ramalama-min image
│   └── Containerfile-qwen-30b # Builds the Qwen-30B application image
├── k8s/                      # Kubernetes manifests (example)
│   ├── deployment-qwen-30b.yaml
│   ├── deployment.yaml
│   ├── fake-secret.yaml
│   └── service.yaml
├── scripts/                  # Build and runtime scripts
│   ├── build-script.sh       # Core script to install dependencies and build llama.cpp
│   └── llama-server.sh       # Script to start the llama.cpp server
├── LICENSE                   # Project license
├── README.md                 # This file
└── olsconfig.yaml            # Example configuration for Ramalama/llama.cpp
```

## Building Images Locally with Podman

It is recommended to use Podman v4 or newer.

### 1. Build the Base Image (`centos-ramalama-min`)

This image contains all the necessary dependencies and the compiled `llama.cpp` binaries.

```bash
# Navigate to the repository root
cd /path/to/this/repo

# Define your desired image name
export IMAGE_OWNER="your-registry-username" # e.g., your GHCR username like "myuser" or quay.io username
export BASE_IMAGE_TAG="${IMAGE_OWNER}/centos-ramalama-min:latest"

podman build \
  -f containerfiles/Containerfile-min \
  -t "${BASE_IMAGE_TAG}" \
  .
```
Replace `your-registry-username` with your actual username or organization for the registry you intend to use (e.g., `ghcr.io/myuser`, `quay.io/myorg`).

### 2. Build an Application Image (e.g., Qwen-4B)

Application images take the base image and add a specific model.

```bash
# Ensure BASE_IMAGE_TAG is set from the previous step
export APP_IMAGE_TAG="${IMAGE_OWNER}/centos-ramalama-qwen-4b:latest"

podman build \
  -f containerfiles/Containerfile \
  --build-arg BASE_IMAGE_NAME="${BASE_IMAGE_TAG}" \
  -t "${APP_IMAGE_TAG}" \
  .
```

To build the Qwen-30B image:
```bash
export APP_IMAGE_QWEN_30B_TAG="${IMAGE_OWNER}/centos-ramalama-qwen-30b:latest"

podman build \
  -f containerfiles/Containerfile-qwen-30b \
  --build-arg BASE_IMAGE_NAME="${BASE_IMAGE_TAG}" \
  -t "${APP_IMAGE_QWEN_30B_TAG}" \
  .
```

## GitHub Actions CI Pipeline

This repository includes a GitHub Actions workflow defined in `.github/workflows/build-images.yml`. This pipeline automates the building and pushing of container images.

**Features:**

*   **Trigger**: Runs on pushes to the `main` branch and on pull requests targeting `main`.
*   **Podman**: Uses Podman for all build operations.
*   **Build Order**:
    1.  Builds the base image (`centos-ramalama-min`).
    2.  Builds the application images (`centos-ramalama-qwen-4b`, `centos-ramalama-qwen-30b`) using the just-built base image.
*   **Registry**: Pushes images to GitHub Container Registry (GHCR) by default when changes are merged to `main`.
    *   Images will be named like `ghcr.io/<your-github-org-or-username>/centos-ramalama-min:latest`.
*   **Tagging**: Images are tagged with `latest` and the Git commit SHA.

**Configuring Registry for Pushing (for forks or different registries):**

If you fork this repository or want to push to a different registry (e.g., your personal Quay.io account):

1.  **Secrets**:
    *   For GHCR (default): The workflow uses `secrets.GITHUB_TOKEN` which is automatically available and has permissions to push to your fork's GHCR if packages are enabled for the repository.
    *   For other registries (e.g., Quay.io, Docker Hub):
        *   You'll need to create repository secrets (e.g., `REGISTRY_USER`, `REGISTRY_TOKEN`).
        *   Update the `podman login` step in `.github/workflows/build-images.yml` to use these secrets and the correct registry URL.
2.  **Environment Variables in Workflow**:
    *   You can change the `REGISTRY` and `IMAGE_OWNER` environment variables at the top of the `.github/workflows/build-images.yml` file if you want to push to a different registry or under a different owner name by default. The `IMAGE_OWNER` defaults to `github.repository_owner`.

## Running the Server

Once an application image is built (e.g., `your-registry-username/centos-ramalama-qwen-4b:latest`), you can run the server. The `scripts/llama-server.sh` script is the default entrypoint or command.

Example:
```bash
podman run -it --rm -p 8080:8080 \
  your-registry-username/centos-ramalama-qwen-4b:latest \
  # Additional arguments for llama-server.sh can be added here
  # For example, to specify a model (though models are baked in these app images):
  # --model /models/qwen2-4b-instruct-q4_k_m.gguf
```
The server typically listens on port 8080. The `olsconfig.yaml` might be used by the server for its configuration, and models are expected to be in the `/models` directory within the container.

## Kubernetes Deployment

Example Kubernetes manifests are provided in the `k8s/` directory. These can be used as a starting point for deploying the Ramalama server to a Kubernetes cluster. You will likely need to customize them, especially regarding image names, resource requests/limits, and any necessary secrets or configmaps.

## Multi-Architecture Images (Future Consideration)

The original README mentioned `podman manifest create` for multi-architecture images. While the current CI pipeline builds for single-architecture (amd64), the `build-script.sh` has some multi-arch awareness.
To build multi-arch images:
1. Build images for each architecture (e.g., `amd64`, `arm64`) separately using `podman build --arch=<architecture> ...`.
2. Create a manifest list and push it:
   ```bash
   podman manifest create my-multiarch-image:latest
   podman manifest add my-multiarch-image:latest docker://your-registry/image:amd64-tag
   podman manifest add my-multiarch-image:latest docker://your-registry/image:arm64-tag
   podman manifest push my-multiarch-image:latest docker://your-registry/my-multiarch-image:latest
   ```
This functionality is not yet automated in the CI pipeline.
