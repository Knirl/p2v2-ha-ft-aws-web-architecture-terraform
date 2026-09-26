#!/bin/bash
set -euxo pipefail

# Update system and install web server + CLI dependencies

dnf install -y httpd unzip

# ---------------------------------------------------------------------------
# S3 Template Sync
# ---------------------------------------------------------------------------
# Attempt to fetch web template package from S3 bucket
if aws s3 cp "s3://${bucket_name}/website.zip" /tmp/website.zip; then
  unzip -o /tmp/website.zip -d /var/www/html/
  rm -f /tmp/website.zip

else
    # Basic HTML fallback if network download fails
    cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head><title>App Server</title></head>
<body>
  <h1>Deployed via Terraform (${project_name}-${environment})</h1>
  <p>Served by instance ID: $(curl -s -H "X-aws-ec2-metadata-token: $(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")" http://169.254.169.254/latest/meta-data/instance-id)</p>
</body>
</html>
EOF
fi

# Ensure permissions and start Apache
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

systemctl enable httpd
systemctl start httpd