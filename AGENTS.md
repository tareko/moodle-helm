# AGENTS.md - Coding Agent Guidelines

This repository contains infrastructure-as-code for deploying Moodle LMS to Kubernetes using Helm charts and Docker.

## Repository Structure

```
.
├── charts/moodle/          # Helm chart for Moodle deployment
│   ├── Chart.yaml          # Chart metadata
│   ├── values.yaml         # Default configuration values
│   ├── values-*.yaml       # Environment-specific values
│   ├── values.schema.json  # Values JSON schema
│   └── templates/          # Kubernetes manifests
├── docker/                 # Container image definitions
│   └── Dockerfile          # Moodle PHP/Apache image
├── tests/                  # Test scripts
│   ├── http_status_test.sh
│   ├── service_smoke_test.sh
│   ├── diagnose_500.sh
│   └── php_config_test.sh
└── .github/workflows/      # GitHub Actions CI/CD
```

## Build/Lint/Test Commands

### Helm Chart

```bash
# Lint the Helm chart
helm lint ./charts/moodle

# Lint with specific values file
helm lint ./charts/moodle -f ./charts/moodle/values-glia.yaml

# Dry-run template rendering (debug)
helm template moodle ./charts/moodle --debug

# Render templates to stdout for review
helm template moodle ./charts/moodle -f ./charts/moodle/values-glia.yaml

# Validate against Kubernetes API (requires kubeconfig)
helm upgrade --install moodle ./charts/moodle --dry-run -n moodle
```

### Docker Image

```bash
# Build image locally
docker build -t moodle:local ./docker

# Build with specific Moodle version
docker build --build-arg MOODLE_VERSION=v5.1.3 -t moodle:5.1.3 ./docker

# Build for multiple platforms
docker buildx build --platform linux/amd64,linux/arm64 -t moodle:test ./docker
```

### Running Tests

```bash
# HTTP status test (requires deployed Moodle)
./tests/http_status_test.sh https://moodle.example.com 200

# Service smoke test
./tests/service_smoke_test.sh https://moodle.example.com

# PHP config test (run inside pod)
kubectl exec -n moodle deployment/moodle -- /bin/sh /tests/php_config_test.sh

# Diagnose 500 errors (update POD_NAME in script first)
./tests/diagnose_500.sh
```

### Kubernetes Debugging (Seeing What's Happening)

**Always use `-n moodle` namespace flag.** These commands are essential for understanding cluster state:

```bash
# View pod status (first command to run)
kubectl -n moodle get pods

# Watch pods in real-time
kubectl -n moodle get pods -w

# View all resources at once
kubectl -n moodle get all,configmaps,secrets,ingresses,gateways,httproutes

# View pod details and events
kubectl -n moodle describe pod <pod-name>

# View logs (most recent)
kubectl -n moodle logs deployment/moodle

# Stream logs in real-time
kubectl -n moodle logs deployment/moodle --tail=100 -f

# View logs from specific pod
kubectl -n moodle logs <pod-name>

# View previous container logs (if crashed)
kubectl -n moodle logs <pod-name> --previous

# Execute commands in pod
kubectl -n moodle exec -it deployment/moodle -- /bin/sh
kubectl -n moodle exec -it <pod-name> -- /bin/sh

# Check configmaps and secrets
kubectl -n moodle get configmaps,secrets
kubectl -n moodle describe configmap moodle-config

# View deployment status
kubectl -n moodle get deployment moodle -o wide

# View recent events (for troubleshooting)
kubectl -n moodle get events --sort-by='.lastTimestamp'

# Check service endpoints
kubectl -n moodle get endpoints

# Port-forward for local testing
kubectl -n moodle port-forward deployment/moodle 8080:8080
```

### Deployment Workflow for Major Changes

After making significant changes to Helm charts or Dockerfiles, follow this workflow:

```bash
# 1. Commit and push changes
git add . && git commit -m "description" && git push

# 2. Monitor GitHub Actions workflow (takes ~35 minutes)
gh run watch

# 3. Verify deployment is running
kubectl -n moodle get pods
kubectl -n moodle logs deployment/moodle --tail=50
```

**Note:** GitHub Actions deployment takes approximately 35 minutes to complete.

## Code Style Guidelines

### Shell Scripts

- Use `#!/bin/sh` for POSIX compatibility when possible; `#!/bin/bash` for bash-specific features
- Always include `set -eu` at minimum; use `set -euo pipefail` for comprehensive error handling
- Quote all variable expansions: `"$VAR"` not `$VAR`
- Use meaningful variable names in UPPER_CASE for environment/config, lower_case for local
- Add usage comments at the top explaining arguments and purpose
- Exit with meaningful codes: 0 for success, non-zero for failure

```sh
#!/bin/sh
set -eu

URL="${1:-http://localhost}"
EXPECTED="${2:-200}"
```

### Helm Charts

- Use helper templates from `_helpers.tpl` for consistent naming and labels
- Template names: `moodle.fullname`, `moodle.labels`, `moodle.selectorLabels`
- Use `{{- include ... | nindent N }}` for consistent indentation
- Prefer `toYaml` for complex object rendering from values
- Use conditional blocks with `{{- if }}` / `{{- end }}` (note the `-` for whitespace control)
- Keep values.yaml well-documented with inline comments
- Use `| quote` for string values that should be quoted in output

```yaml
metadata:
  name: {{ include "moodle.fullname" . }}
  labels:
    {{- include "moodle.labels" . | nindent 4 }}
```

### YAML (Kubernetes Manifests)

- 2-space indentation
- Include standard labels: `app.kubernetes.io/name`, `app.kubernetes.io/instance`
- Use `toYaml` for resource blocks from values
- Set reasonable resource requests/limits

### Dockerfile

- Use specific image tags, not `latest`
- Combine RUN commands with `&&` to reduce layers
- Clean up apt cache: `rm -rf /var/lib/apt/lists/*`
- Set `USER` directive for non-root execution where possible
- Use ARG for build-time variables with sensible defaults

### Environment Variables

- Database credentials come from Kubernetes secrets
- Use `secretKeyRef` for sensitive values, `configMapRef` for config
- Follow naming convention: `MOODLE_*` for Moodle-specific vars

## Architecture Notes

- Moodle runs as non-root (UID 33 - www-data)
- Apache listens on port 8080 (not 80)
- Document root: `/var/www/html/public`
- Config file mounted from ConfigMap at `/var/www/html/public/config.php`
- Redis is deployed alongside Moodle for caching
- PostgreSQL is external (managed service)
- File storage uses S3-compatible object storage (DigitalOcean Spaces)
- Gateway API used for ingress (not Ingress resource)

## Common Patterns

### Adding a New Config Value

1. Add to `values.yaml` with default and comment
2. Reference in template: `{{ .Values.some.value | quote }}`
3. Update `values.schema.json` if validation needed

### Adding a New Template

1. Check `_helpers.tpl` for existing patterns
2. Use `{{- define "moodle.something" -}}` syntax
3. Keep templates focused and reusable

### Adding a New Test

1. Create script in `tests/` with `.sh` extension
2. Add `set -eu` or `set -euo pipefail`
3. Include usage comment header
4. Make executable: `chmod +x tests/new_test.sh`
