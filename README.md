# Moodle Helm + Image CI/CD

This repository now includes:

- Helm chart: `charts/moodle`
- Image build + deploy workflow: `.github/workflows/moodle-build-and-deploy.yml`
- Production-oriented Moodle image Dockerfile: `docker/Dockerfile`

## Required GitHub secrets

- `KUBECONFIG_B64`: base64-encoded kubeconfig for your DOKS cluster

## Optional GitHub Actions repository variables

- `HELM_RELEASE_NAME` (default: `moodle`)
- `K8S_NAMESPACE` (default: `moodle`)

## How CI/CD works

1. On push to `main` (changes under `charts/moodle`, `docker`, or workflow), GitHub Actions builds and pushes image to GHCR.
2. Workflow deploys via Helm and overrides:
   - `image.repository` to GHCR image repo
   - `image.tag` to generated tag

## Notes on Moodle version selection

- Dockerfile uses `ARG MOODLE_VERSION` with default `MOODLE_405_STABLE`.
- To pin another stable branch, adjust build args in workflow (future enhancement) or change Dockerfile default.

