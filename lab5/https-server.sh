#!/bin/bash
set -euo pipefail
# Run on lab5-app through IAP. Debian supplies OpenSSL; no package download needed.
sudo install -d -m 700 /run/lab5
sudo openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout /run/lab5/key.pem -out /run/lab5/cert.pem -subj /CN=lab5-app 2>/dev/null
sudo systemd-run --unit=lab5-https --property=Restart=on-failure \
  openssl s_server -accept 443 -cert /run/lab5/cert.pem -key /run/lab5/key.pem -www
