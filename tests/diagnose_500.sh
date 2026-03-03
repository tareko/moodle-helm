#!/bin/bash
# Comprehensive diagnostic script for Moodle 500 error
set -euo pipefail

POD_NAME="moodle-69b86fb9c9-bw265"
NAMESPACE="moodle"

echo "=== Moodle 500 Error Diagnostic ==="
echo ""

echo "1. Checking PHP extensions available..."
kubectl exec -n $NAMESPACE $POD_NAME -- php -m 2>&1 | grep -E "(pgsql|pdo)" || echo "No pgsql-related extensions found"
echo ""

echo "2. Checking config.php content..."
kubectl exec -n $NAMESPACE $POD_NAME -- cat /var/www/html/config.php 2>&1
echo ""

echo "3. Testing PHP config.php execution..."
kubectl exec -n $NAMESPACE $POD_NAME -- php -r "try { require('/var/www/html/config.php'); echo 'SUCCESS: config.php loaded'; } catch (Exception \$e) { echo 'ERROR: ' . \$e->getMessage(); }" 2>&1 || echo "PHP execution failed"
echo ""

echo "4. Checking Apache error log..."
kubectl exec -n $NAMESPACE $POD_NAME -- cat /var/log/apache2/error.log 2>&1 | head -20 || echo "Error log not accessible"
echo ""

echo "5. Checking Apache access log..."
kubectl exec -n $NAMESPACE $POD_NAME -- cat /var/log/apache2/access.log 2>&1 | tail -10 || echo "Access log not accessible"
echo ""

echo "6. Checking web directory permissions..."
kubectl exec -n $NAMESPACE $POD_NAME -- ls -la /var/www/html/config.php 2>&1
echo ""

echo "7. Testing PDO PostgreSQL connection..."
kubectl exec -n $NAMESPACE $POD_NAME -- php -r "
\$pdo = new PDO('pgsql:host=localhost;dbname=moodle', 'moodle', '');
echo 'PDO connection successful';
" 2>&1 || echo "PDO connection failed"
echo ""

echo "=== Diagnostic Complete ==="