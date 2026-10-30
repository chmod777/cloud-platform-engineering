#!/bin/bash
set -euo pipefail
# Run on lab5-mgmt; pass the private app address returned by Terraform.
: "${1:?Usage: probe.sh APP_PRIVATE_IP}"
[[ "$1" =~ ^10\.10\.1\.[0-9]+$ ]] || { echo 'Expected an app-subnet address.' >&2; exit 2; }
echo 'Internal HTTPS (self-signed lab certificate; identity is not verified):'
curl -k --connect-timeout 5 --max-time 10 --silent --output /dev/null --write-out 'HTTP %{http_code}\n' "https://$1" || echo "Internal HTTPS failed: curl exit $?"
echo 'External HTTPS with certificate verification:'
curl --connect-timeout 5 --max-time 10 --silent --output /dev/null --write-out 'HTTP %{http_code}\n' https://example.com || echo "External HTTPS failed: curl exit $?"
echo 'External HTTP (expected denial when HTTPS-only egress is enabled):'
curl --connect-timeout 5 --max-time 10 --silent --output /dev/null --write-out 'HTTP %{http_code}\n' http://example.com || echo "External HTTP failed: curl exit $?"
