# File Storage Fix - Summary

## Problem

Uploaded files worked temporarily then stopped working because:
1. The `tool_objectfs` and `local_aws` plugins were NOT installed in the Docker image
2. Files were being stored locally in the container's ephemeral filesystem
3. When Kubernetes pods restarted, all uploaded files were lost
4. The S3/Spaces configuration in Helm values was being ignored

## Root Cause

The Dockerfile only installed:
- Moodle core
- `mod_booking` plugin
- `local_wunderbyte_table` plugin

But was MISSING:
- `tool_objectfs` plugin (required for S3 storage)
- `local_aws` plugin (required for AWS SDK/S3 API)

Without these plugins, the environment variables `MOODLE_OBJECTFS_*` were being ignored and files were stored locally.

## Changes Made

### 1. Updated Dockerfile (`docker/Dockerfile`)

Added installation of required S3 plugins:
```dockerfile
&& git clone --depth 1 https://github.com/catalyst/moodle-tool_objectfs.git /var/www/html/public/admin/tool/objectfs \
&& rm -rf /var/www/html/public/admin/tool/objectfs/.git \
&& git clone --depth 1 https://github.com/catalyst/moodle-local_aws.git /var/www/html/public/local/aws \
&& rm -rf /var/www/html/public/local/aws/.git \
```

### 2. Updated ConfigMap Template (`charts/moodle/templates/moodle-config-configmap.yaml`)

Added S3 filesystem configuration:
```php
if (filter_var(getenv('MOODLE_OBJECTFS_ENABLED') ?: 'false', FILTER_VALIDATE_BOOLEAN)) {
  $CFG->alternative_file_system_class = '\\tool_objectfs\\s3_file_system';
  $CFG->objectfs = new stdClass();
  $CFG->objectfs->key = getenv('MOODLE_OBJECTFS_S3_KEY') ?: '';
  $CFG->objectfs->secret = getenv('MOODLE_OBJECTFS_S3_SECRET') ?: '';
  $CFG->objectfs->bucket = getenv('MOODLE_OBJECTFS_S3_BUCKET') ?: '';
  $CFG->objectfs->region = getenv('MOODLE_OBJECTFS_S3_REGION') ?: '';
  $CFG->objectfs->endpoint = getenv('MOODLE_OBJECTFS_S3_ENDPOINT') ?: '';

  // Use path-style endpoint for DigitalOcean Spaces
  if (filter_var(getenv('MOODLE_OBJECTFS_S3_PATH_STYLE') ?: 'false', FILTER_VALIDATE_BOOLEAN)) {
    $CFG->objectfs->use_path_style_endpoint = true;
  }

  // Extend presigned URL expiration to 7 days
  $CFG->objectfs_presigned_url_expiry = 604800;
}
```

## Next Steps

### 1. Rebuild and Deploy the Docker Image

```bash
# Build new image with S3 plugins
docker build -t ghcr.io/tareko/moodle:with-s3-support -f docker/Dockerfile .

# Push to registry
docker push ghcr.io/tareko/moodle:with-s3-support

# Update values-glia.yaml to use new image tag
# image:
#   tag: "with-s3-support"

# Deploy via Helm
helm upgrade moodle ./charts/moodle \
  --namespace moodle \
  --values ./charts/moodle/values-glia.yaml \
  --set image.tag=with-s3-support
```

### 2. Configure Object Storage in Moodle

After deployment, navigate to:
- **Site administration → Plugins → Admin tools → Object storage file system**

Configure settings:
- Enable file transfer tasks: **Yes**
- Storage File System Selection: **Amazon S3**
- Key, Secret, Bucket, Region: (Already configured via environment variables)
- Minimum size threshold: **0 KB** (All files to S3)
- Minimum age: **0 days** (Immediate transfer)
- Delete local objects: **Yes** (After consistency delay)
- Consistency delay: **1 day**

### 3. Verify Configuration

Check that files are being stored in Spaces:
```bash
# List files in Spaces bucket
aws s3 ls s3://moodle-glia/ --endpoint-url=https://tor1.digitaloceanspaces.com

# Check Moodle filedir
kubectl exec -n moodle deployment/moodle -- ls -la /tmp/moodledata/filedir/
```

### 4. Test File Upload

1. Upload a test file to a course
2. Verify it's accessible via the file URL
3. Check that it exists in the Spaces bucket
4. Restart the pod and verify file is still accessible (proving it's in S3, not local)

## Configuration Options

The config.php now supports these environment variables (already set in values-glia.yaml):
- `MOODLE_OBJECTFS_ENABLED`: Enable/disable S3 storage
- `MOODLE_OBJECTFS_S3_KEY`: DigitalOcean Spaces access key
- `MOODLE_OBJECTFS_S3_SECRET`: DigitalOcean Spaces secret key
- `MOODLE_OBJECTFS_S3_BUCKET`: Bucket name (moodle-glia)
- `MOODLE_OBJECTFS_S3_REGION`: Region (tor1)
- `MOODLE_OBJECTFS_S3_ENDPOINT`: S3 endpoint (tor1.digitaloceanspaces.com)
- `MOODLE_OBJECTFS_S3_PATH_STYLE`: Use path-style endpoint (true for Spaces)

## Benefits

1. **Persistent storage**: Files stored in DigitalOcean Spaces, not lost on pod restart
2. **Scalability**: Multiple pods can access the same files
3. **Cost-effective**: Only pay for storage used, not local disk
4. **7-day presigned URLs**: Files remain accessible for a week before URLs need refreshing
5. **Performance**: S3 offloads file serving from Moodle application servers

## Troubleshooting

If files still don't work after deployment:

1. Check plugin is installed: `Site administration → Plugins → Admin tools`
2. Check PHP error logs: `kubectl logs -n moodle deployment/moodle`
3. Verify S3 credentials: Check `moodle-spaces-credentials` secret
4. Test S3 access manually with AWS CLI
5. Check Moodle config: Verify `$CFG->alternative_file_system_class` is set correctly

## References

- [Moodle tool_objectfs Plugin](https://moodle.org/plugins/tool_objectfs)
- [DigitalOcean Spaces Documentation](https://docs.digitalocean.com/products/spaces/)
- [Helm Chart Configuration](./charts/moodle/values-glia.yaml)
