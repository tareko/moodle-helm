#!/bin/sh
set -eu

# Test script to verify PHP configuration and database connection
# This test should be run inside the Moodle pod

echo "=== PHP Configuration Test ==="

# Check if pgsql extension is available
echo "Checking for pgsql extension..."
if php -m | grep -qi '^pgsql$'; then
  echo "PASS: Native pgsql extension is available"
else
  echo "FAIL: Native pgsql extension is NOT available"
  echo "Available PDO drivers:"
  php -i 2>&1 | grep "PDO drivers"
  exit 1
fi

# Check if pdo_pgsql extension is available
echo "Checking for pdo_pgsql extension..."
if php -m | grep -qi 'pdo_pgsql'; then
  echo "PASS: pdo_pgsql extension is available"
else
  echo "FAIL: pdo_pgsql extension is NOT available"
  exit 1
fi

# Check if config.php can be parsed
echo "Checking if config.php can be loaded..."
if php -r "require '/var/www/html/config.php';" 2>&1; then
  echo "PASS: config.php loaded successfully"
else
  echo "FAIL: config.php failed to load"
  exit 1
fi

# Check database connection
echo "Testing database connection..."
DB_HOST="${MOODLE_DB_HOST:-localhost}"
DB_PORT="${MOODLE_DB_PORT:-5432}"
DB_NAME="${MOODLE_DB_NAME:-moodle}"
DB_USER="${MOODLE_DB_USER:-moodle}"
DB_PASS="${MOODLE_DB_PASSWORD:-}"

php -r "
try {
    \$dbh = new PDO('pgsql:host=$DB_HOST;port=$DB_PORT;dbname=$DB_NAME', '$DB_USER', '$DB_PASS');
    echo 'PASS: Database connection successful' . PHP_EOL;
    exit(0);
} catch (PDOException \$e) {
    echo 'FAIL: Database connection failed: ' . \$e->getMessage() . PHP_EOL;
    exit(1);
}
" 2>&1

echo "=== All tests passed ==="