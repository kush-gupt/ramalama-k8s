# 🚀 Ramalama Kubernetes - Easy LLM Deployment Made Simple

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![OpenShift](https://img.shields.io/badge/OpenShift-EE0000?style=flat&logo=redhatopenshift&logoColor=white)](https://openshift.com)

> **Deploy powerful Language Models (LLMs) in Kubernetes with just a few commands!**

## What is this?

Ramalama with Kubernetes makes it incredibly easy to run your own ChatGPT-like AI models in Kubernetes or OpenShift. Whether you're a developer, DevOps engineer, or AI enthusiast, this project helps you:

- **Get started quickly** - Deploy AI models in minutes, not hours
- **Use familiar tools** - Works with Docker, Kubernetes, and standard GitOps workflows
- **Production ready** - Includes monitoring, scaling, and security best practices
- **Model variety** - Support for multiple LLM models and sizes
- **Enterprise grade** - Built for OpenShift with proper RBAC and security policies

## Features

### **GitOps Architecture**
```mermaid
graph LR
    A[📝 Git Repo] --> B[🔄 ArgoCD]
    B --> C[☸️ Kubernetes]
    C --> D[🤖 LLM Models]
    
    style A fill:#e1f5fe
    style B fill:#f3e5f5
    style C fill:#e8f5e8
    style D fill:#fff3e0
```

- **Declarative Deployments** - Everything as code with Kustomize
- **Auto-scaling** - Horizontal pod autoscaling based on demand  
- **Security First** - Pod security standards and RBAC
- **Monitoring Ready** - Prometheus metrics and health checks

### 🎭 **Multiple Model Support**

| Model | Size | Use Case | Status |
|-------|------|----------|---------|
| **Qwen 3 1.7B** | Small | 💬 Chat, Q&A | ✅ Ready |
| **Qwen 3 4B** | Medium | 💼 Business tasks | ✅ Ready |  
| **Qwen 3 30B** | Large | 🧠 Complex reasoning | ✅ Ready |
| **DeepSeek R1** | 8B | 🔬 Research tasks | ✅ Ready |

### **Developer Experience**

- **Quick Setup** - One command deployment
- **Easy Configuration** - YAML-based model definitions
- **API Compatible** - OpenAI-compatible endpoints
- **Auto-discovery** - Automatic service discovery for OpenShift Lightspeed

## 🚀 Quick Start

### Prerequisites

![Kubernetes](https://img.shields.io/badge/Kubernetes-1.24+-blue?logo=kubernetes)
![OpenShift](https://img.shields.io/badge/OpenShift-4.15+-red?logo=redhatopenshift)
![Podman](https://img.shields.io/badge/Podman-4.0+-purple?logo=podman)

- **Kubernetes/OpenShift cluster** with admin access
- **Container runtime** (Podman recommended, Docker works if you insist)
- **kubectl/oc CLI** configured

### 1️⃣ Clone and Explore

```bash
git clone https://github.com/kush-gupt/ramalama-k8s.git
cd ramalama-k8s
```

### 2️⃣ Deploy Your First Model

#### **Single Model (Recommended)**
```bash
# 🏗️ Create namespace
oc apply -f k8s/models/ramalama-namespace.yaml

# 🚀 Deploy Qwen 3 1B model on CPU 
oc apply -k k8s/models/qwen3-1b

# ✅ Verify deployment
oc get pods -l model=qwen3-4b -n ramalama
```

#### **Environment-Based Deployment**
```bash
# 🧪 Development environment
oc apply -k k8s/overlays/dev

# 🏭 Production environment  
oc apply -k k8s/overlays/production
```

### 3️⃣ Test Your Model

```bash
# 🔗 Port forward to access the API
oc port-forward -n ramalama svc/qwen3-4b-ramalama-service 8080:8080

# 💬 Test the chat API
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-4b-model",
    "messages": [{"role": "user", "content": "Hello! How are you?"}],
    "temperature": 0.7
  }'
```

## 🎛️ **OpenShift Lightspeed Integration**

![OpenShift Lightspeed](https://img.shields.io/badge/OpenShift%20Lightspeed-Ready-brightgreen?logo=redhatopenshift)

Turn your deployed models into an AI-powered OpenShift assistant!

### 📋 **Prerequisites**
```bash
# ✅ Ensure you have at least one model running first
oc get pods -l app.kubernetes.io/name=ramalama -n ramalama

# 🚀 If no project or models are deployed, deploy one first:
oc apply -f k8s/models/ramalama-namespace.yaml
oc apply -k k8s/models/qwen3-4b
```

### 🎯 **Deployment Options**

#### **Option 1: GitOps Deployment (Recommended)**
```bash
# 🔥 Deploy with ArgoCD - single command handles timing automatically
oc apply -f k8s/lightspeed/argocd/application-qwen3-4b.yaml

# ✅ Monitor deployment
oc get applications -n openshift-gitops | grep lightspeed
```

#### **Option 2: Direct Kustomize (Two-Step Process)**
Due to operator timing dependencies, direct deployment requires two steps:

```bash
# 🔧 Step 1: Install operator and create CRDs
oc apply -k k8s/lightspeed/base/operator-only

# ⏳ Step 2: Wait for operator to be ready (this creates the required CRDs)
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=lightspeed-operator -n openshift-lightspeed --timeout=300s

# 🎯 Step 3: Apply complete configuration
oc apply -k k8s/lightspeed/overlays/qwen3-4b
```

### **What You Get**
- **AI Assistant** integrated into OpenShift console
- **YAML Generation** - "Create a deployment for nginx"  
- **Troubleshooting** - "Why is my pod failing?"
- **Best Practices** - Expert OpenShift guidance
- **Auto-discovery** - Automatically connects to your deployed models

### **Verification**
```bash
# ✅ Check all components are running
oc get pods -n openshift-lightspeed
oc get olsconfig cluster -n openshift-lightspeed
```

[📖 **Detailed Lightspeed Setup Guide**](k8s/lightspeed/README.md)

## 🏗️ **Architecture Overview**

```mermaid
graph TB
    subgraph "🚀 GitOps Layer"
        G[📝 Git Repository]
        A[🔄 ArgoCD/OpenShift GitOps]
    end
    
    subgraph "☸️ Kubernetes Cluster"
        subgraph "🤖 ramalama namespace"
            M1[📦 qwen3-1b-deployment]
            M2[📦 qwen3-4b-deployment] 
            M3[📦 qwen3-30b-deployment]
            M4[📦 deepseek-r1-deployment]
        end
        
        subgraph "🎯 openshift-lightspeed namespace"
            LS[🤖 Lightspeed Assistant]
        end
    end
    
    subgraph "👨‍💻 User Interfaces"
        CLI[🖥️ kubectl/oc CLI]
        WEB[🌐 OpenShift Console]
        API[🔌 REST APIs]
    end
    
    G --> A
    A --> M1
    A --> M2  
    A --> M3
    A --> M4
    A --> LS
    
    LS -.->|🔗 Connects to| M2
    LS -.->|🔗 Connects to| M3
    LS -.->|🔗 Connects to| M4
    
    CLI --> M1
    CLI --> M2
    WEB --> LS
    API --> M1
    API --> M2
    
    style G fill:#e1f5fe
    style A fill:#f3e5f5
    style M1 fill:#e8f5e8
    style M2 fill:#e8f5e8
    style M3 fill:#e8f5e8  
    style M4 fill:#e8f5e8
    style LS fill:#fff3e0
```

## **Model Management**

### **Add New Models**

![Add Model](https://img.shields.io/badge/Script-add--model.sh-blue?logo=gnu-bash)

```bash
# 🎯 Interactive mode
./scripts/add-model.sh --interactive

# 🚀 Command line mode with Lightspeed generation
./scripts/add-model.sh \
  --name "llama-7b" \
  --description "Llama 7B Chat model" \
  --model-gguf-url "hf://microsoft/Llama-7b-gguf" \
  --model-file "/mnt/models/llama-7b.gguf/llama-7b.gguf" \
  --create-lightspeed-overlay
```

**Auto-Generated Files:**
- 📦 `containerfiles/Containerfile-llama-7b`
- ☸️ `k8s/models/llama-7b/kustomization.yaml`
- 🎯 `k8s/lightspeed/overlays/llama-7b/kustomization.yaml`
- 🤖 `k8s/lightspeed/overlays/llama-7b/olsconfig.yaml`
- 📖 `k8s/lightspeed/overlays/llama-7b/README.md`
- ⚙️ `models/llama-7b.conf`

### **List Models**
```bash
./scripts/list-models.sh
```

### **Remove Models**
```bash
./scripts/remove-model.sh llama-7b --force
```

### **Deployment Order (Important!)**

When deploying both models and OpenShift Lightspeed:

```bash
# 1️⃣ Deploy model first
oc apply -f k8s/models/ramalama-namespace.yaml
oc apply -k k8s/models/llama-7b

# 2️⃣ Wait for model to be ready
oc wait --for=condition=Ready pod -l model=llama-7b -n ramalama --timeout=300s

# 3️⃣ Then deploy Lightspeed (two-step process)
oc apply -k k8s/lightspeed/base/operator-only
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=lightspeed-operator -n openshift-lightspeed --timeout=100s
oc apply -k k8s/lightspeed/overlays/llama-7b
```

> [!IMPORTANT]  
> **Model First, Then Lightspeed**: Always deploy your models before deploying OpenShift Lightspeed to ensure proper service discovery and connectivity.

## **Production-like Deployment**

### **With OpenShift GitOps**

![GitOps](https://img.shields.io/badge/GitOps-Enabled-green?logo=argo)

```bash
# 🔄 Single model application
oc apply -f k8s/argocd/application-example.yaml

# 🌍 Multi-environment ApplicationSet
oc apply -f k8s/argocd/applicationset-example.yaml
```

### 📊 **Resource Requirements**

| Model Size | Memory | CPU | GPU | Storage |
|------------|--------|-----|-----|---------|
| **1.7B** | 4Gi | 2 cores | Optional | 10Gi |
| **4B** | 8Gi | 4 cores | Optional | 20Gi |
| **8B** | 16Gi | 8 cores | Recommended | 40Gi |
| **30B** | 32Gi | 16 cores | Required | 80Gi |

### 🔐 **Security Features**

- **Pod Security Standards** - Restricted policies enforced
- **Non-root execution** - All containers run as non-root user
- **RBAC** - Role-based access control
- **Network Policies** - Micro-segmentation ready
- **Security Context** - Dropped capabilities and seccomp

## 📁 **Project Structure**

```
ramalama-k8s/
├── 📦 containerfiles/           # Container build definitions
├── ☸️ k8s/                      # Kubernetes manifests
│   ├── 🏗️ base/                 # Base Kustomize resources  
│   ├── 🎭 models/               # Model-specific configs
│   ├── 🌍 overlays/             # Environment overlays
│   ├── 🎯 lightspeed/           # OpenShift Lightspeed integration
│   └── 🔄 argocd/               # GitOps applications
├── 🤖 models/                   # Model configurations
├── 🛠️ scripts/                  # Management scripts
└── 📚 docs/                     # Documentation
```

## **Configuration**

### **Model Parameters**
```yaml
# Example model configuration
configMapGenerator:
- name: ramalama-config
  literals:
  - CTX_SIZE=20048        # 🧠 Context window size
  - THREADS=14            # 🔄 CPU threads
  - TEMP=0.7              # 🌡️ Temperature (creativity)
  - TOP_K=40              # 🎯 Top-K sampling
  - TOP_P=0.9             # 📊 Top-P sampling
```

### **Environment Variables**
```bash
# 🚪 API Configuration
PORT=8080
HOST=0.0.0.0

# 🧠 Model Settings  
MODEL_FILE=/mnt/models/model.gguf
CTX_SIZE=4096
THREADS=14

# �� Server Options
LOG_COLORS=true
NO_WARMUP=false
JINJA=true
```

## **Monitoring & Troubleshooting**

### **Health Checks**
```bash
# ✅ Check model health
oc get pods -l app.kubernetes.io/name=ramalama -n ramalama

# 📝 View logs
oc logs -l model=qwen3-4b -n ramalama --tail=100

# 🔧 Debug service connectivity
oc port-forward -n ramalama svc/qwen3-4b-ramalama-service 8080:8080
curl http://localhost:8080/v1/models
```

### 🆘 **Common Issues**

| Issue | Solution |
|-------|----------|
| 🚫 Pod not starting | Check resource limits and node capacity |
| 🔌 API not responding | Verify port-forward and service endpoints |  
| 🐌 Slow responses | Increase CPU/memory or enable GPU |
| 📦 Image pull errors | Check registry credentials and image tags |

## 🤝 **Contributing**

![Contributors](https://img.shields.io/badge/Contributors-Welcome-brightgreen?logo=github)

1. **🍴 Fork** the repository
2. **🌿 Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **💾 Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **📤 Push** to the branch (`git push origin feature/amazing-feature`)
5. **🔄 Open** a Pull Request

### **Development Setup**
```bash
# 🏠 Local development
./scripts/build-script.sh
podman build -f containerfiles/Containerfile-min .

# 🧪 Test locally
./scripts/llama-server.sh
```

## 📚 **Documentation**

- **[Kubernetes Deployment Guide](k8s/README.md)**
- **[OpenShift Lightspeed Integration](k8s/lightspeed/README.md)**  
- **[Model Management](MODELS.md)**
- **[GitOps Setup](OPENSHIFT_GITOPS.md)**

## 📜 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋 **Support**

- **🐛 Issues**: [GitHub Issues](https://github.com/kush-gupt/ramalama-k8s/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/kush-gupt/ramalama-k8s/discussions)
---

**🎉 Ready to deploy your own AI models?**

[![Get Started](https://img.shields.io/badge/Get%20Started-Now-success?style=for-the-badge&logo=rocket)](k8s/README.md)
[![OpenShift Lightspeed](https://img.shields.io/badge/OpenShift%20Lightspeed-Deploy-red?style=for-the-badge&logo=redhatopenshift)](k8s/lightspeed/README.md)

*Made for the open source community*
