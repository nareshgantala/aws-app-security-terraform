#!/usr/bin/env bash
# ==============================================================================
# Production EC2 Bootstrap Script (Amazon Linux 2023 / RHEL 9)
# ==============================================================================
set -Eeuo pipefail

# Redirect stdout & stderr to both console and a dedicated bootstrap log
exec > >(tee -a /var/log/user-data-bootstrap.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting EC2 User Data Bootstrap Process..."

# ------------------------------------------------------------------------------
# 1. Environment & Dynamic AWS Metadata Resolution (IMDSv2)
# ------------------------------------------------------------------------------
# Securely retrieve IMDSv2 session token (TTL: 60s)
IMDS_TOKEN=$(curl -s -S -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
AWS_REGION=$(curl -s -S -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" "http://169.254.169.254/latest/meta-data/placement/region")
INSTANCE_ID=$(curl -s -S -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" "http://169.254.169.254/latest/meta-data/instance-id")

export AWS_DEFAULT_REGION="$AWS_REGION"
SECRET_ID="my-predefined-db-secret" # Change to your Secrets Manager secret name or pass via templatefile

echo "[INFO] Running on Instance: ${INSTANCE_ID} in Region: ${AWS_REGION}"

# ------------------------------------------------------------------------------
# 2. Package Installation (AWS CLI, CloudWatch Agent, Node.js, Python, Nginx)
# ------------------------------------------------------------------------------
echo "[INFO] Installing base packages and runtimes..."
dnf update -y
dnf install -y \
    unzip \
    jq \
    nginx \
    python3 \
    python3-pip \
    nodejs \
    amazon-cloudwatch-agent

# Ensure latest AWS CLI v2 is present (if not pre-packaged)
if ! command -v aws &> /dev/null; then
    echo "[INFO] Installing AWS CLI v2..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install --update
    rm -rf /tmp/aws /tmp/awscliv2.zip
fi

# ------------------------------------------------------------------------------
# 3. Fetch Database Secrets via IAM Role & Secrets Manager
# ------------------------------------------------------------------------------
echo "[INFO] Fetching application configuration from Secrets Manager..."

# Query secret directly using attached IAM Instance Profile
SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "${SECRET_ID}" \
    --query "SecretString" \
    --output text)

if [[ -z "$SECRET_JSON" ]]; then
    echo "[ERROR] Failed to fetch secret ${SECRET_ID} or secret is empty!"
    exit 1
fi

# Parse connection string or individual keys
DB_CONNECTION_STRING=$(echo "$SECRET_JSON" | jq -r '.DB_CONNECTION_STRING // .url // empty')
DB_USER=$(echo "$SECRET_JSON" | jq -r '.username // "app_user"')

# Store securely in runtime env file with restricted permissions
mkdir -p /etc/app
cat <<EOF > /etc/app/production.env
NODE_ENV=production
PORT=3000
DATABASE_URL=${DB_CONNECTION_STRING}
DB_USER=${DB_USER}
EOF

chmod 600 /etc/app/production.env
echo "[INFO] App secrets configured at /etc/app/production.env"

# ------------------------------------------------------------------------------
# 4. Deploy Sample Application & Systemd Unit
# ------------------------------------------------------------------------------
echo "[INFO] Setting up Application Directory and Service..."

# Dedicated system user and app log structure
useradd -r -s /sbin/nologin appuser || true
mkdir -p /opt/app /var/log/app
chown -R appuser:appuser /opt/app /var/log/app

# Minimal Node.js HTTP Server that writes structured logs to /var/log/app/app.log
cat <<'EOF' > /opt/app/server.js
const http = require('http');
const fs = require('fs');

const port = process.env.PORT || 3000;
const logFile = '/var/log/app/app.log';

function log(level, message) {
    const entry = JSON.stringify({
        timestamp: new Date().toISOString(),
        level: level,
        message: message
    }) + '\n';
    fs.appendFileSync(logFile, entry);
}

const server = http.createServer((req, res) => {
    if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'UP' }));
        return;
    }
    
    log('INFO', `Handled request to ${req.url} from ${req.socket.remoteAddress}`);
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('Application is running securely via SSM & Private VPC.\n');
});

server.listen(port, () => {
    log('INFO', `Server initialized on port ${port}`);
});
EOF

chown -R appuser:appuser /opt/app

# Create systemd service for Node.js
cat <<EOF > /etc/systemd/system/node-app.service
[Unit]
Description=Production Node.js Application
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/app
EnvironmentFile=/etc/app/production.env
ExecStart=/usr/bin/node /opt/app/server.js
Restart=always
RestartSec=5
StandardOutput=append:/var/log/app/app.log
StandardError=append:/var/log/app/app.log

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------------------------
# 5. Reverse Proxy Configuration (Nginx -> Node App)
# ------------------------------------------------------------------------------
cat <<'EOF' > /etc/nginx/conf.d/app.conf
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

# ------------------------------------------------------------------------------
# 6. Configure & Start AWS CloudWatch Agent (Logs + Disk + Memory Metrics)
# ------------------------------------------------------------------------------
echo "[INFO] Configuring CloudWatch Agent..."

cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/app/app.log",
            "log_group_name": "/aws/ec2/production/app",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 14
          },
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/aws/ec2/production/nginx-access",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/user-data-bootstrap.log",
            "log_group_name": "/aws/ec2/production/bootstrap",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "\${aws:InstanceId}",
      "AutoScalingGroupName": "\${aws:AutoScalingGroupName}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent",
          "mem_available",
          "mem_total"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent",
          "free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      }
    }
  }
}
EOF

# ------------------------------------------------------------------------------
# 7. Start Services & Verify
# ------------------------------------------------------------------------------
echo "[INFO] Starting all system services..."

systemctl daemon-reload
systemctl enable --now node-app
systemctl enable --now nginx

# Start and apply CloudWatch agent configuration
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bootstrap successfully completed."