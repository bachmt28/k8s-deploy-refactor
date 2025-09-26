# k8s-deploy-refactor

Helm-ified version of the original Kustomize deployment templates. The `charts/workload` chart
contains templated manifests for the workload Deployment/StatefulSet, Service, Istio resources,
ConfigMaps, Secrets, HPA and optional persistent volumes.

## Quick start

```bash
helm template los-clos charts/workload -f charts/workload/values-uat.yaml --set image.tag=1.0.0
```

Use additional values files or `--set` flags to adapt the chart for other environments.