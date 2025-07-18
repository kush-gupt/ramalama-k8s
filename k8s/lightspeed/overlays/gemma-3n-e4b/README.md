# OpenShift Lightspeed with gemma-3n-e4b

This overlay configures OpenShift Lightspeed to use the gemma-3n-e4b model deployed in the `ramalama` namespace.

## Prerequisites

Ensure you have the gemma-3n-e4b model running:
```bash
oc get pods -l model=gemma-3n-e4b -n ramalama
```

If not deployed, deploy it first:
```bash
oc apply -f ../../models/ramalama-namespace.yaml
oc apply -k ../../models/gemma-3n-e4b
```

## Deployment

Due to the timing dependency between operator installation and CRD creation, deployment requires two steps:

### Step 1: Install the OpenShift Lightspeed Operator
```bash
oc apply -k ../../base/operator-only
```

Wait for the operator to be ready (this creates the required CRDs):
```bash
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=lightspeed-operator -n openshift-lightspeed --timeout=300s
```

### Step 2: Apply the Complete Configuration
```bash
oc apply -k .
```

## Verification

Check that all components are running:
```bash
# Check operator
oc get pods -l app.kubernetes.io/name=lightspeed-operator -n openshift-lightspeed

# Check lightspeed components
oc get pods -l app.kubernetes.io/name=lightspeed-app-server -n openshift-lightspeed

# Check OLS configuration
oc get olsconfig cluster -n openshift-lightspeed
```

## Usage

1. Access the OpenShift web console
2. Look for the Lightspeed assistant icon in the navigation
3. Start asking questions about your cluster!

Example questions:
- "How do I create a deployment?"
- "Show me pods that are not running"
- "Generate a service YAML for my application"

## Cleanup

To remove the deployment:
```bash
oc delete -k .
oc delete -k ../../base/operator-only
```
