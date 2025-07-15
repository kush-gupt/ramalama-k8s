#!/usr/bin/env python3

"""
generate-from-config.py - Generate Containerfiles, k8s deployments, and workflow from YAML config
"""

import argparse
import os
import sys
import yaml
from pathlib import Path
from typing import Dict, Any
import re

class ModelGenerator:
    def __init__(self, config_path: str, repo_root: str):
        self.config_path = Path(config_path)
        self.repo_root = Path(repo_root)
        self.config = self._load_config()
        
        # Ensure directories exist
        self.containerfiles_dir = self.repo_root / "containerfiles"
        self.k8s_dir = self.repo_root / "k8s"
        self.models_dir = self.repo_root / "models"
        self.scripts_dir = self.repo_root / "scripts"
        self.workflow_dir = self.repo_root / ".github" / "workflows"
        self.lightspeed_dir = self.repo_root / "k8s" / "lightspeed" / "overlays"
        
        for dir_path in [self.containerfiles_dir, self.k8s_dir, self.models_dir, self.lightspeed_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)

    def _load_config(self) -> Dict[str, Any]:
        """Load and validate the YAML configuration."""
        try:
            with open(self.config_path, 'r') as f:
                config = yaml.safe_load(f)
            return config
        except Exception as e:
            print(f"Error loading config: {e}")
            sys.exit(1)

    def _sanitize_name(self, name: str) -> str:
        """Sanitize model name for file names."""
        return re.sub(r'[^a-z0-9-]', '-', name.lower()).strip('-')

    def _merge_config(self, model_config: Dict[str, Any], model_key: str) -> Dict[str, Any]:
        """Merge model config with defaults and templates."""
        # Start with global defaults
        merged = self.config.get('defaults', {}).copy()
        
        # Apply template if specified
        template_name = model_config.get('template')
        if template_name and template_name in self.config.get('templates', {}):
            template = self.config['templates'][template_name]
            # Merge template parameters
            if 'parameters' in template:
                merged.setdefault('parameters', {}).update(template['parameters'])
            # Merge template resources
            if 'resources' in template:
                resource_size = model_config.get('resource_size', 'small')
                if resource_size in template['resources']:
                    merged.setdefault('resources', {}).update(template['resources'][resource_size])
        
        # Apply model-specific config
        for key, value in model_config.items():
            if isinstance(value, dict) and key in merged and isinstance(merged[key], dict):
                merged[key].update(value)
            else:
                merged[key] = value
        
        # Add computed values
        merged['model_key'] = model_key
        merged['model_name_safe'] = self._sanitize_name(model_key)
        
        # Set default model_source if not provided
        if 'model_source' not in merged:
            merged['model_source'] = f"{merged['model_name_safe']}-source"
        
        return merged

    def generate_containerfile(self, model_key: str, model_config: Dict[str, Any]) -> str:
        """Generate Containerfile content."""
        template = """ARG BASE_IMAGE_NAME
ARG MODEL_SOURCE_NAME
FROM ${{BASE_IMAGE_NAME}}

ARG MODEL_SOURCE_NAME

# Copy the entire /models directory from the model source
# into the final application image at /mnt/models.
COPY --from=${{MODEL_SOURCE_NAME}} /models /mnt/models

# This is a sanity check for OpenShift's random user ID.
USER root
RUN chmod -R a+rX /mnt/models
USER 1001

# Optional: Add labels to describe your new all-in-one image
LABEL maintainer="{maintainer}"
LABEL description="{description}"
"""
        
        return template.format(
            maintainer=model_config.get('maintainer', 'Unknown'),
            description=model_config.get('description', f'{model_config["name"]} model')
        )

    def generate_k8s_kustomization(self, model_key: str, model_config: Dict[str, Any]) -> tuple[str, str]:
        """Generate Kustomization files for GitOps deployment."""
        model_name_safe = model_config['model_name_safe']
        params = model_config.get('parameters', {})
        registry_path = self.config.get('defaults', {}).get('registry_path', 'ghcr.io/kush-gupt')
        app_image_url = f"{registry_path}/{model_name_safe}-ramalama"
        
        # Generate kustomization.yaml
        kustomization_yaml = f"""apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: ramalama-{model_name_safe}
  annotations:
    argocd.argoproj.io/sync-wave: "1"

resources:
  - ../base-model

namePrefix: {model_name_safe}-

commonLabels:
  app.kubernetes.io/instance: {model_name_safe}
  model: {model_name_safe}

# Model-specific configuration
configMapGenerator:
  - name: model-config
    behavior: replace
    literals:
      - MODEL_NAME={model_config.get('name', model_name_safe)}
      - MODEL_FILE={model_config.get('model_file', '/mnt/models/model.gguf')}
      - ALIAS={model_name_safe}-model

# Model-specific image
images:
  - name: MODEL_IMAGE
    newName: {app_image_url}
    newTag: latest

# Model-specific parameters via configmap merge
configMapGenerator:
  - name: ramalama-config
    behavior: merge
    literals:
      - CTX_SIZE={params.get('ctx_size', 4096)}
      - THREADS={params.get('threads', 14)}
      - TEMP={params.get('temp', 0.7)}
      - TOP_K={params.get('top_k', 40)}
      - TOP_P={params.get('top_p', 0.9)}
      - CACHE_REUSE={params.get('cache_reuse', 256)}"""

        # Generate model-specific patch if needed
        resources = model_config.get('resources', {})
        model_patch = ""
        if resources:
            model_patch = f"""apiVersion: apps/v1
kind: Deployment
metadata:
  name: ramalama-deployment
spec:
  template:
    spec:
      containers:
      - name: ramalama
        resources:"""
            if 'requests' in resources:
                model_patch += f"""
          requests:
            memory: "{resources['requests'].get('memory', '4Gi')}"
            cpu: "{resources['requests'].get('cpu', '2')}\""""
            if 'limits' in resources:
                model_patch += f"""
          limits:
            memory: "{resources['limits'].get('memory', '8Gi')}"
            cpu: "{resources['limits'].get('cpu', '4')}\""""
            
            kustomization_yaml += f"""

# Model-specific resource patches  
patchesStrategicMerge:
  - model-patch.yaml"""
        
        return kustomization_yaml, model_patch

    def generate_lightspeed_overlay(self, model_key: str, model_config: Dict[str, Any]) -> str:
        """Generate OpenShift Lightspeed overlay."""
        model_name_safe = model_config['model_name_safe']
        lightspeed_namespace = model_config.get('lightspeed_namespace', 'ramalama')
        
        overlay_yaml = f"""apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: openshift-lightspeed-{model_name_safe}
  annotations:
    argocd.argoproj.io/sync-wave: "2"

resources:
  - ../../base

patches:
  - target:
      kind: OLSConfig
      name: cluster
    patch: |-
      - op: replace
        path: /spec/llm/providers/0/url
        value: http://{model_name_safe}-ramalama-service.{lightspeed_namespace}.svc.cluster.local:8080/v1
      - op: replace
        path: /spec/llm/providers/0/models/0/name
        value: default
      - op: add
        path: /metadata/labels/model
        value: {model_name_safe}
      - op: add
        path: /metadata/labels/environment
        value: {model_name_safe}
  - target:
      kind: Secret
      name: credentials
    patch: |-
      - op: add
        path: /metadata/labels/model
        value: {model_name_safe}
      - op: add
        path: /metadata/labels/environment
        value: {model_name_safe}
  - target:
      kind: Subscription
      name: lightspeed-operator
    patch: |-
      - op: add
        path: /metadata/labels/model
        value: {model_name_safe}
      - op: add
        path: /metadata/labels/environment
        value: {model_name_safe}"""
        
        return overlay_yaml

    def generate_workflow_job(self, model_key: str, model_config: Dict[str, Any]) -> tuple[str, str]:
        """Generate GitHub workflow job content."""
        model_name_safe = model_config['model_name_safe']
        env_var_name = f"APP_IMAGE_{model_name_safe.upper().replace('-', '_')}_NAME_SUFFIX"
        
        job_content = f"""
  build-app-image-{model_name_safe}:
    name: Build App Image ({model_config["name"]})
    runs-on: ubuntu-latest
    needs: [determine-image-owner, build-base-image]
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Turn off IPv6
        run: |
          sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
          sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

      - name: Upgrade to Podman 5
        run: |
          # Enable universe repository which contains podman
          sudo add-apt-repository "deb http://archive.ubuntu.com/ubuntu oracular universe"
          # Update package lists
          sudo apt-get update
          sudo apt-get purge firefox
          # Install specific podman version
          sudo apt-get upgrade

      - name: Print Disk Space
        shell: bash
        run: |
          df -h

      - name: Free Disk Space
        shell: bash
        run: |
          sudo docker rmi "$(docker image ls -aq)" >/dev/null 2>&1 || true
          sudo rm -rf \\
            /usr/share/dotnet /usr/local/lib/android /opt/ghc \\
            /usr/local/share/powershell /usr/share/swift /usr/local/.ghcup \\
            /usr/share/dotnet /usr/lib/jvm /opt/hostedtoolcache/CodeQL \\
            "$AGENT_TOOLSDIRECTORY" || true
          sudo swapoff -a
          sudo rm -f /mnt/Swapfile

      # /mnt has ~ 65 GB free disk space. / is too small.
      - name: Reconfigure data-root
        run: |
          sudo mkdir -p /mnt/docker /etc/docker
          echo '{{"data-root": "/mnt/docker"}}' > /tmp/daemon.json
          sudo mv /tmp/daemon.json /etc/docker/daemon.json
          cat /etc/docker/daemon.json
          sudo systemctl restart docker.service
          df -h

      - name: Log in to GitHub Container Registry
        run: echo "${{{{ secrets.GITHUB_TOKEN }}}}" | podman login ${{{{ env.REGISTRY }}}} -u ${{{{ github.actor }}}} --password-stdin

      - name: Define Image Tags and Build Args
        id: image_details
        run: |
          OWNER_PATH="${{{{ needs.determine-image-owner.outputs.registry_owner_path }}}}"
          BASE_IMAGE_LATEST="${{OWNER_PATH}}/${{{{ env.BASE_IMAGE_NAME_SUFFIX }}}}:latest"
          APP_IMAGE_BASENAME="${{{{ env.{env_var_name} }}}}"
          TAG_LATEST="${{OWNER_PATH}}/${{APP_IMAGE_BASENAME}}:latest"
          TAG_SHA="${{OWNER_PATH}}/${{APP_IMAGE_BASENAME}}:${{{{ github.sha }}}}"
          echo "BASE_IMAGE_ARG=${{BASE_IMAGE_LATEST}}" >> $GITHUB_OUTPUT
          echo "TAG_LATEST=${{TAG_LATEST}}" >> $GITHUB_OUTPUT
          echo "TAG_SHA=${{TAG_SHA}}" >> $GITHUB_OUTPUT
          echo "All tags to build: ${{TAG_LATEST}}, ${{TAG_SHA}}"
          echo "Base image for build-arg: ${{BASE_IMAGE_LATEST}}"

      - name: Build {model_config["name"]} app image
        run: |
          sudo podman --storage-driver overlay --root='/mnt/docker' --runroot='/run/containers' build --squash-all \\
            --format=oci \\
            --build-arg BASE_IMAGE_NAME=${{{{ steps.image_details.outputs.BASE_IMAGE_ARG }}}} \\
            --build-arg MODEL_SOURCE_NAME={model_config.get('model_source', 'unknown')} \\
            --tag ${{{{ steps.image_details.outputs.TAG_LATEST }}}} \\
            --tag ${{{{ steps.image_details.outputs.TAG_SHA }}}} \\
            -f ./containerfiles/Containerfile-{model_name_safe} \\
            .

      - name: Push {model_config["name"]} app image
        run: |
          sudo podman --storage-driver overlay --root='/mnt/docker' --runroot='/run/containers' push ${{{{ steps.image_details.outputs.TAG_LATEST }}}}
          sudo podman --storage-driver overlay --root='/mnt/docker' --runroot='/run/containers' push ${{{{ steps.image_details.outputs.TAG_SHA }}}}"""
        
        return job_content, env_var_name

    def generate_all(self):
        """Generate all files for all models in the configuration."""
        if 'models' not in self.config:
            print("No models found in configuration")
            return

        print(f"Generating files for {len(self.config['models'])} models...")
        
        env_vars = []
        workflow_jobs = []
        lightspeed_count = 0
        
        for model_key, model_config in self.config['models'].items():
            print(f"Processing model: {model_key}")
            
            # Merge configuration
            merged_config = self._merge_config(model_config, model_key)
            model_name_safe = merged_config['model_name_safe']
            
            # Generate Containerfile
            containerfile_content = self.generate_containerfile(model_key, merged_config)
            containerfile_path = self.containerfiles_dir / f"Containerfile-{model_name_safe}"
            with open(containerfile_path, 'w') as f:
                f.write(containerfile_content)
            print(f"  Generated: {containerfile_path}")
            
            # Generate k8s kustomization
            kustomization_content, model_patch = self.generate_k8s_kustomization(model_key, merged_config)
            model_dir = self.k8s_dir / "models" / model_name_safe
            model_dir.mkdir(parents=True, exist_ok=True)
            
            kustomization_path = model_dir / "kustomization.yaml"
            with open(kustomization_path, 'w') as f:
                f.write(kustomization_content)
            print(f"  Generated: {kustomization_path}")
            
            # Generate model patch if needed
            if model_patch:
                patch_path = model_dir / "model-patch.yaml"
                with open(patch_path, 'w') as f:
                    f.write(model_patch)
                print(f"  Generated: {patch_path}")
            
            # Generate Lightspeed overlay if requested
            if merged_config.get('create_lightspeed_overlay', False):
                lightspeed_content = self.generate_lightspeed_overlay(model_key, merged_config)
                lightspeed_model_dir = self.lightspeed_dir / model_name_safe
                lightspeed_model_dir.mkdir(parents=True, exist_ok=True)
                
                lightspeed_path = lightspeed_model_dir / "kustomization.yaml"
                with open(lightspeed_path, 'w') as f:
                    f.write(lightspeed_content)
                print(f"  Generated: {lightspeed_path}")
                lightspeed_count += 1
            
            # Generate workflow job
            job_content, env_var_name = self.generate_workflow_job(model_key, merged_config)
            workflow_jobs.append(job_content)
            env_vars.append(f"  {env_var_name}: {model_name_safe}-ramalama")
            
            # Generate model configuration file
            config_content = f"""# Configuration for {merged_config["name"]}
MODEL_NAME="{merged_config["name"]}"
MODEL_DESCRIPTION="{merged_config.get('description', '')}"
MODEL_GGUF_URL="{merged_config.get('model_gguf_url', '')}"
MODEL_SOURCE="{merged_config.get('model_source', '')}"
MODEL_FILE="{merged_config.get('model_file', '')}"
CTX_SIZE={merged_config.get('parameters', {}).get('ctx_size', 4096)}
THREADS={merged_config.get('parameters', {}).get('threads', 14)}
TEMP={merged_config.get('parameters', {}).get('temp', 0.7)}
TOP_K={merged_config.get('parameters', {}).get('top_k', 40)}
TOP_P={merged_config.get('parameters', {}).get('top_p', 0.9)}
CACHE_REUSE={merged_config.get('parameters', {}).get('cache_reuse', 256)}
MAINTAINER="{merged_config.get('maintainer', 'Unknown')}"
CREATE_LIGHTSPEED_OVERLAY={str(merged_config.get('create_lightspeed_overlay', False)).lower()}
LIGHTSPEED_NAMESPACE="{merged_config.get('lightspeed_namespace', 'default')}"
"""
            config_path = self.models_dir / f"{model_name_safe}.conf"
            with open(config_path, 'w') as f:
                f.write(config_content)
            print(f"  Generated: {config_path}")

        # Note: No workflow update needed with modular system
        print(f"\nNote: Using modular workflow - no manual workflow updates needed!")
        print("The workflow will automatically discover models from models.yaml")
        
        print("\nGeneration completed successfully!")
        print(f"Generated files for {len(self.config['models'])} models")
        if lightspeed_count > 0:
            print(f"Generated {lightspeed_count} OpenShift Lightspeed overlays")

    def _update_workflow(self, env_vars: list, workflow_jobs: list):
        """Update the GitHub workflow with new environment variables and jobs."""
        workflow_path = self.workflow_dir / "build-images.yml"
        
        if not workflow_path.exists():
            print(f"Warning: Workflow file not found at {workflow_path}")
            return
        
        # Create backup
        backup_path = workflow_path.with_suffix('.yml.backup')
        with open(workflow_path, 'r') as src, open(backup_path, 'w') as dst:
            dst.write(src.read())
        
        with open(workflow_path, 'r') as f:
            content = f.read()
        
        # Add environment variables after existing APP_IMAGE variables
        env_section = '\n'.join(env_vars)
        
        # Find the last APP_IMAGE variable and add new ones after it
        pattern = r'(\s*APP_IMAGE.*_NAME_SUFFIX:.*\n)'
        matches = list(re.finditer(pattern, content))
        if matches:
            last_match = matches[-1]
            insert_pos = last_match.end()
            content = content[:insert_pos] + env_section + '\n' + content[insert_pos:]
        
        # Add jobs before the last line
        jobs_content = '\n'.join(workflow_jobs)
        content = content.rstrip() + jobs_content + '\n'
        
        with open(workflow_path, 'w') as f:
            f.write(content)
        
        print(f"  Updated: {workflow_path}")
        print(f"  Backup: {backup_path}")

def main():
    parser = argparse.ArgumentParser(description='Generate model files from YAML configuration')
    parser.add_argument('--config', '-c', default='models/models.yaml',
                       help='Path to the YAML configuration file')
    parser.add_argument('--repo-root', '-r', default='.',
                       help='Path to the repository root')
    
    args = parser.parse_args()
    
    # Determine repository root
    repo_root = Path(args.repo_root).resolve()
    config_path = repo_root / args.config
    
    if not config_path.exists():
        print(f"Error: Configuration file not found: {config_path}")
        sys.exit(1)
    
    generator = ModelGenerator(str(config_path), str(repo_root))
    generator.generate_all()

if __name__ == '__main__':
    main() 