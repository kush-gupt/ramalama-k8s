# Ramalama Modelcar Images

This repository contains the necessary files to build minimal modelcar images with Ramalama to easily serve GGUFs with a single container in Kubernetes or OpenShift using `llama.cpp`.

The images are intended to be built using Podman and include a base image with dependencies and demo application images with specific models.

## Repository Structure

The repository is organized as follows:

```
.
├── .github/workflows/        
│   └── build-images.yml      # CI pipeline for building and pushing images
├── containerfiles/
│   ├── Containerfile-min         # Builds the base image           
│   ├── Containerfile-qwen-4b     # Builds the Qwen-4B application image
│   └── Containerfile-qwen-30b    # Builds the Qwen-30B MOE application image
├── k8s/                      # Kubernetes manifests
│   ├── deployment-qwen-4b.yaml   # Example deployment for smaller model
│   ├── deployment-qwen-30b.yaml  # Example deployment for larger MOE model
│   ├── fake-secret.yaml          # Fake secret for OpenShift Lightspeed
│   ├── service.yaml              # Example service for Ramalama OpenAI compatible API
│   └── olsconfig.yaml            # Example configuration for OpenShift Lightspeed
│
├── scripts/                  # Build and runtime scripts
│   ├── build-script.sh       # Core script to install dependencies and build llama.cpp
│   └── llama-server.sh       # Script to start the llama.cpp server
├── LICENSE                   # Project license
└── README.md                 # This file
```

## Building Images Locally with Podman

It is recommended to use Podman 5 or newer.

### 1. Build the Base Image (`centos-ramalama-min`)

This image contains all the necessary dependencies and the compiled `llama.cpp` binaries.

```bash
# Navigate to the repository root
cd /path/to/this/repo

# Define your desired image name
export IMAGE_OWNER="your-registry/username" # e.g., your GHCR username like "ghcr.io/myuser" or "quay.io/username"
export BASE_IMAGE_TAG="${IMAGE_OWNER}/centos-ramalama-min:latest"

podman build \
  -f containerfiles/Containerfile-min \
  -t "${BASE_IMAGE_TAG}" \
  .
```
Replace `your-registry-username` with your actual username or organization for the registry you intend to use (e.g., `ghcr.io/myuser`, `quay.io/myorg`).

### 2. Build an Application Image (e.g., Qwen-4B)

Use Ramalama to create a raw OCI image first:
```bash
# Install Ramalama through script
curl -fsSL https://ramalama.ai/install.sh | bash
...

# Pull a smaller model of your choice, for Qwen-4B
ramalama pull hf://unsloth/Qwen3-4B-GGUF/Qwen3-4B-Q4_K_M.gguf

# Make this image your model source in the next Containerfiles.
export MODEL_SOURCE_NAME='${IMAGE_OWNER}/qwen3-4b:latest'

# Toss that into an OCI image:
ramalama convert hf://unsloth/Qwen3-4B-GGUF/Qwen3-4B-Q4_K_M.gguf oci://${MODEL_SOURCE_NAME}

# Push to a registry of your choice:
podman push ${MODEL_SOURCE_NAME}
```

Application images take the centos base image and add this OCI model into it.

To build the Qwen-4B image:

```bash
# Ensure BASE_IMAGE_TAG is set from the previous step
export APP_IMAGE_TAG="${IMAGE_OWNER}/qwen-4b-ramalama:latest"

podman build \
  -f containerfiles/Containerfile-qwen-4b \
  --build-arg BASE_IMAGE_NAME="${BASE_IMAGE_TAG}" \
  --build-arg MODEL_SOURCE_NAME="${MODEL_SOURCE_NAME}" \
  -t "${APP_IMAGE_TAG}" \
  .
```

To build the Qwen-30B image:
```bash
export APP_IMAGE_QWEN_30B_TAG="${IMAGE_OWNER}/qwen-30b-ramalama:latest"

podman build \
  -f containerfiles/Containerfile-qwen-30b \
  --build-arg BASE_IMAGE_NAME="${BASE_IMAGE_TAG}" \
  --build-arg MODEL_SOURCE_NAME="${MODEL_SOURCE_NAME}" \
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
    *   Images will be named like `ghcr.io/<your-github-username>/centos-ramalama-min:latest`.
*   **Tagging**: Images are tagged with `latest` and the Git commit SHA.

**Configuring Registry for Pushing (for forks or different registries):**

If you fork this repository or want to push to a different registry (e.g., your Quay.io account):

1.  **Secrets**:
    *   For GHCR (default): The workflow uses `secrets.GITHUB_TOKEN` which is automatically available and has permissions to push to your fork's GHCR if packages are enabled for the repository.
    *   For other registries (e.g., Quay.io, Docker Hub):
        *   You'll need to create repository secrets (e.g., `REGISTRY_USER`, `REGISTRY_TOKEN`).
        *   Update the `podman login` step in `.github/workflows/build-images.yml` to use these secrets and the correct registry URL.
2.  **Environment Variables in Workflow**:
    *   You can change the `REGISTRY` and `IMAGE_OWNER` environment variables at the top of the `.github/workflows/build-images.yml` file if you want to push to a different registry or under a different owner name by default. The `IMAGE_OWNER` defaults to `github.repository_owner`.

## Running the Server

Once an application image is built (e.g., `your-registry-username/qwen-4b-ramalama:latest`), you can run the server. The `scripts/llama-server.sh` script is the default entrypoint or command.

Example:
```bash
podman run -it --rm -p 8080:8080 \
  ${IMAGE_OWNER}/qwen-4b-ramalama:latest \
  # Additional arguments for llama-server.sh can be added here
  # For example, to specify a model (though models are baked in these app images):
  # --model /models/Qwen3-4B-Q4_K_M.gguf/Qwen3-4B-Q4_K_M.gguf
```
The server listens on port 8080 by default.

## Kubernetes Deployment

Example Kubernetes manifests are provided in the `k8s/` directory. These can be used as a starting point for deploying the Ramalama server to a Kubernetes cluster. You will likely need to customize them, especially regarding image names, resource requests/limits, threads, and any necessary secrets and/or configmaps. The `olsconfig.yaml` may be used by OpenShift Lightspeed for its configuration, and models are expected to be in the `/models` directory within the container.

## Multi-Architecture Images

While the current CI pipeline builds for single-architecture (amd64), the `build-script.sh` has multi-arch awareness.
To build multi-arch images:
1. Build images for each architecture (e.g., `amd64`, `arm64`) separately using `podman build --arch=<architecture> ...`.
2. Create a manifest list and push it:
   ```bash
   podman manifest create my-multiarch-image:latest
   podman manifest add my-multiarch-image:latest docker://your-registry/image:amd64-tag
   podman manifest add my-multiarch-image:latest docker://your-registry/image:arm64-tag
   podman manifest push my-multiarch-image:latest docker://your-registry/my-multiarch-image:latest
   ```
ARM containers are not yet automated in the CI pipeline, they're done manually by Kush.

Let Kush know if you'd like to see specific images in this repo!
