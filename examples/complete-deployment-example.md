# Complete Deployment Example: Ramalama + OpenShift Lightspeed

This example shows how to deploy a complete AI-powered OpenShift environment with LLM models and intelligent assistance.

## 🎯 What We'll Deploy

- **Ramalama Models**: Qwen 3 4B model for general AI assistance
- **OpenShift Lightspeed**: AI-powered cluster management assistant
- **GitOps Integration**: Automated deployment and management

## 📋 Prerequisites

- OpenShift 4.17+ cluster with cluster-admin access
- ArgoCD installed (optional but recommended)
- At least 8GB RAM and 4 CPU cores available
- Container registry access (ghcr.io, quay.io, or your own OCI registry)

## 🚀 Step-by-Step Deployment

### Step 1: Deploy a Ramalama Model

Choose one of these methods:

#### Option A: ArgoCD
```bash
# Deploy Qwen 3 4B model using ArgoCD
kubectl apply -f k8s/argocd/application-example.yaml

# Check deployment status
argocd app get ramalama-qwen-4b-dev
argocd app sync ramalama-qwen-4b-dev
```

#### Option B: Direct Kustomize
```bash
# Deploy directly to default namespace
oc apply -k k8s/models/qwen3-4b

# Check pods are running
oc get pods -l model=qwen3-4b
oc get svc -l model=qwen3-4b
```

### Step 2: Verify Model Service

```bash
# Check that the model service is accessible
oc get svc qwen3-4b-ramalama-service

# Port forward to test locally (optional and mainly for local clusters)
oc port-forward svc/qwen3-4b-ramalama-service 8080:8080

# Test the model API
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [
      {"role": "user", "content": "Hello! How are you?"}
    ],
    "max_tokens": 100
  }'
```

### Step 3: Deploy OpenShift Lightspeed

Now deploy OpenShift Lightspeed that will connect to your running model:

#### Option A: Using ArgoCD ApplicationSet (All Models)
```bash
# Deploy Lightspeed for all available models
kubectl apply -f k8s/lightspeed/argocd/applicationset-lightspeed.yaml

# Check ArgoCD applications
argocd app list | grep lightspeed
```

#### Option B: Deploy for Specific Model
```bash
# Deploy Lightspeed configured for Qwen 3 4B
oc apply -k k8s/lightspeed/overlays/qwen3-4b

# Check deployment
oc get pods -n openshift-lightspeed
oc get olsconfig -n openshift-lightspeed
```

#### Option C: Auto-Discovery
```bash
# Deploy with auto-discovery (points to hardcoded model list of services)
oc apply -k k8s/lightspeed/overlays/auto-discovery
```

### Step 4: Verify OpenShift Lightspeed

```bash
# Check operator installation
oc get subscription lightspeed-operator -n openshift-lightspeed

# Check OLS configuration
oc describe olsconfig cluster -n openshift-lightspeed

# Check all pods are running
oc get pods -n openshift-lightspeed

# View logs
oc logs -l app.kubernetes.io/name=lightspeed-service -n openshift-lightspeed
```

### Step 5: Access the AI Assistant

1. **Open OpenShift Web Console**
2. **Look for the Lightspeed icon** (usually an AI icon in the bottom right)
3. **Start asking questions**:
   - "How do I scale a deployment?"
   - "Generate a ConfigMap YAML"
   - "What's wrong with my failing pods?"
   - "What tools do you have access to?"

## 🔧 Adding New Models with Lightspeed

### Using the Enhanced Model Management

You can now add new models that automatically include OpenShift Lightspeed integration:

```bash
# Add a new model with Lightspeed overlay
./scripts/add-model.sh \
  --name "llama-7b" \
  --description "Llama 7B Chat model" \
  --model-gguf-url "hf://ggml-org/llama-7b/llama-7b.gguf" \
  --model-file "/mnt/models/llama-7b.gguf/llama-7b.gguf" \
  --create-lightspeed-overlay \
  --lightspeed-namespace "ramalama"
```

This creates:
- Containerfile for the model
- Kubernetes deployment in `k8s/models/llama-7b/`
- OpenShift Lightspeed overlay in `k8s/lightspeed/overlays/llama-7b/`
- Model configuration file

### Deploy the New Model and Lightspeed manually

```bash
# Build and push the source image first
ramalama convert hf://ggml-org/llama-7b/llama-7b.gguf oci://ghcr.io/your-user/llama-7b-source:latest

# Add a new model with Lightspeed overlay
./scripts/add-model.sh \
  --name "llama-7b" \
  --description "Llama 7B Chat model" \
  --model-gguf-url "hf://ggml-org/llama-7b/llama-7b.gguf" \
  --model-file "/mnt/models/llama-7b.gguf/llama-7b.gguf" \
  --create-lightspeed-overlay \
  --lightspeed-namespace "ramalama"

# Deploy the model
oc apply -k k8s/models/llama-7b

# Deploy Lightspeed for this model
oc apply -k k8s/lightspeed/overlays/llama-7b
```

## 🔍 Troubleshooting

### Model Not Connecting to Lightspeed

1. **Check service names and namespaces**:
   ```bash
   # Verify model service exists
   oc get svc -l model=qwen3-4b
   
   # Check the actual service name matches the olsconfig
   oc get olsconfig cluster -n openshift-lightspeed -o yaml | grep url
   ```

2. **Test connectivity**:
   ```bash
   # Create a test pod to check connectivity
   oc run test-pod --rm -i --tty --image=curlimages/curl -- sh
   
   # From inside the pod:
   curl http://qwen3-4b-ramalama-service.ramalama.svc.cluster.local:8080/v1/models
   ```

3. **Check credentials**:
   ```bash
   # Verify the credentials secret
   oc get secret credentials -n openshift-lightspeed -o yaml
   ```

### Lightspeed Not Appearing in Console

1. **Check operator status**:
   ```bash
   oc get subscription lightspeed-operator -n openshift-lightspeed
   oc get csv -n openshift-lightspeed
   ```

2. **Check OLS configuration**:
   ```bash
   oc describe olsconfig cluster -n openshift-lightspeed
   ```

3. **View operator logs**:
   ```bash
   oc logs -l app.kubernetes.io/name=lightspeed-operator -n openshift-lightspeed
   ```

## 🎛️ Configuration Examples

### Environment-Specific Configuration

You can create environment-specific configurations:

```yaml
# k8s/lightspeed/overlays/production-qwen3-4b/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patches:
  - target:
      kind: OLSConfig
      name: cluster
    patch: |-
      - op: replace
        path: /spec/llm/providers/0/url
        value: http://qwen3-4b-ramalama-service.ramalama.svc.cluster.local:8080/v1
      - op: replace
        path: /spec/ols/logLevel
        value: ERROR
      - op: replace
        path: /spec/ols/deployment/replicas
        value: 2

commonLabels:
  model: qwen3-4b
  environment: production
```

### Multiple Model Configuration

For environments with multiple models, use the auto-discovery overlay:

```bash
# Deploy auto-discovery which can switch between models
kubectl apply -k k8s/lightspeed/overlays/auto-discovery

# The auto-discovery service can be updated to point to different models
kubectl edit svc ramalama-discovery -n openshift-lightspeed
```

### Resource Scaling

Monitor and adjust resources based on usage:

```bash
# Check resource usage
kubectl top pods -n openshift-lightspeed

# Scale the deployment if needed
kubectl patch olsconfig cluster -n openshift-lightspeed \
  --type merge \
  --patch '{"spec":{"ols":{"deployment":{"replicas":3}}}}'
```

## ✅ Success Criteria

Your deployment is successful when:

1. ✅ **Model is running**: `kubectl get pods -l model=qwen3-4b` shows Running
2. ✅ **Service is accessible**: Model API responds to health checks
3. ✅ **Lightspeed operator is active**: Subscription shows Succeeded
4. ✅ **OLS config is applied**: `kubectl get olsconfig` shows cluster config
5. ✅ **Console integration works**: Lightspeed icon appears in OpenShift console
6. ✅ **AI responses work**: Questions in the console get intelligent responses

## 🎉 What's Next?

Once deployed, you can:

- **Scale your models** based on usage patterns
- **Add more models** for different use cases
- **Customize prompts** and model behavior
- **Monitor performance** and adjust resources
- **Integrate with CI/CD** for automated model updates

## 📚 Additional Resources

- [OpenShift Lightspeed Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_lightspeed)
- [Model Management Guide](../MODELS.md)
- [Troubleshooting Guide](../k8s/lightspeed/README.md#troubleshooting)
- [Ramalama Website](https://ramalama.ai)

---

**🚀 Ready to revolutionize your OpenShift experience with AI assistance?**

Follow this guide and start asking your cluster questions in natural language! 🤖✨ 