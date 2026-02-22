# Moodle Helm + Image CI/CD

This repository now includes:

- Helm chart: `charts/moodle`
- Image build + deploy workflow: `.github/workflows/moodle-build-and-deploy.yml`
- Production-oriented Moodle image Dockerfile: `docker/Dockerfile`

## One-time prerequisites

- A Kubernetes cluster with Gateway API CRDs installed.
- cert-manager installed and a `ClusterIssuer` named `letsencrypt-prod` (or adjust values).
- A Gateway compatible with your cluster (or enable chart Gateway creation in values).

## Kubernetes namespace + runtime secrets (created locally with kubectl)

These secrets are consumed by the chart and stay in your cluster namespace.

1. Create namespace:

```bash
kubectl create namespace moodle
```

2. PostgreSQL connection secret (external managed PostgreSQL):

```bash
kubectl -n moodle create secret generic moodle-postgresql \
  --from-literal=host='YOUR_PG_HOST' \
  --from-literal=port='5432' \
  --from-literal=database='YOUR_DB_NAME' \
  --from-literal=username='YOUR_DB_USER' \
  --from-literal=password='YOUR_DB_PASSWORD'
```

3. DigitalOcean Spaces credentials secret:

```bash
kubectl -n moodle create secret generic moodle-spaces-credentials \
  --from-literal=access-key-id='YOUR_SPACES_KEY' \
  --from-literal=secret-access-key='YOUR_SPACES_SECRET'
```

4. Moodle admin password secret:

```bash
kubectl -n moodle create secret generic moodle-admin \
  --from-literal=password='YOUR_STRONG_ADMIN_PASSWORD'
```

## Required GitHub secrets

- `KUBECONFIG_B64`: base64-encoded kubeconfig for your DOKS cluster

### How to create `KUBECONFIG_B64`

1. Base64 encode your current kubeconfig (Linux):

```bash
base64 -w 0 "$HOME/.kube/config"
```

Copy the full output.

2. Add secret in GitHub:

- Repository → **Settings** → **Secrets and variables** → **Actions**
- **New repository secret**
- Name: `KUBECONFIG_B64`
- Value: paste the base64 string

Do **not** commit kubeconfig files to git.

## Optional GitHub Actions repository variables

- `HELM_RELEASE_NAME` (default: `moodle`)
- `K8S_NAMESPACE` (default: `moodle`)

## Install manually with Helm (optional)

Use the example values as a starting point:

```bash
helm upgrade --install moodle ./charts/moodle \
  --namespace moodle \
  --create-namespace \
  --values ./charts/moodle/values-doks-example.yaml
```

## How CI/CD works

1. On push to `main` (changes under `charts/moodle`, `docker`, or workflow), GitHub Actions builds and pushes image to GHCR.
2. Workflow deploys via Helm and overrides:
   - `image.repository` to GHCR image repo
   - `image.tag` to generated tag

## Notes on Moodle version selection

- Dockerfile uses `ARG MOODLE_VERSION` with default `v5.1.3`.
- To pin another stable branch, adjust build args in workflow (future enhancement) or change Dockerfile default.
