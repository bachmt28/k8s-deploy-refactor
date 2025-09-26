# Workload Helm chart

This chart re-packages the manifests that previously lived under `example-workload` into a
configurable Helm chart. It is designed to let Jenkins or other automation pass parameters instead
of replacing `<PLACEHOLDER>` tokens with `sed`.

## Structure

* `Chart.yaml` – chart metadata.
* `values.yaml` – default configuration for the workload, service, HPA, Istio objects and the static
  persistent volume example.
* `values-uat.yaml` – opinionated overlay that mirrors the former `uat` Kustomize overlays.
* `templates/` – Kubernetes manifests rendered from the values above.

## Usage

```bash
# Render manifests locally
helm template los-clos charts/workload -f charts/workload/values-uat.yaml \
  --set image.tag=1.2.3

# Install into a namespace
helm upgrade --install los-clos charts/workload -n los --create-namespace \
  -f charts/workload/values-uat.yaml \
  --set image.tag=1.2.3
```

Override any value either through additional `-f` files or `--set/--set-string`. Secrets should be
supplied at deploy time using `--set-string` or `--set-file`; the sample values use placeholders only.
