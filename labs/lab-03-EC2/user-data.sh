#!/bin/bash

dnf update -y
dnf install -y nginx

systemctl enable nginx
systemctl start nginx

cat > /usr/share/nginx/html/index.html <<'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>USMS Web Server</title>
</head>
<body>
    <h1>USMS Web Server</h1>
    <p>EC2 instance is running successfully.</p>
</body>
</html>
HTML

mkdir -p /usr/share/nginx/html/health

cat > /usr/share/nginx/html/health/health.json <<'JSON'
{
  "status": "healthy",
  "service": "usms-web",
  "lab": "03"
}
JSON
