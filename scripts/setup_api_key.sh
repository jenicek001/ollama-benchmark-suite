#!/bin/bash
# Ollama API Key Setup Script
# This script sets up nginx as a reverse proxy with API key authentication

set -e

echo "========================================"
echo "🔐 Ollama API Key Setup"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  This script needs sudo privileges"
    echo "Please run: sudo ./setup_api_key.sh"
    exit 1
fi

# Install nginx
echo "1️⃣  Installing nginx..."
apt update
apt install -y nginx

# Generate a secure API key
echo ""
echo "2️⃣  Generating secure API key..."
API_KEY=$(openssl rand -hex 32)
echo "   Your API key: $API_KEY"
echo "   (Save this! You'll need it for your clients)"

# Create nginx configuration
echo ""
echo "3️⃣  Creating nginx configuration..."
cat > /etc/nginx/sites-available/ollama << EOF
# Map to check API key
map \$http_x_api_key \$api_key_valid {
    default 0;
    "$API_KEY" 1;
}

server {
    listen 8080;
    server_name _;

    # Return proper JSON error
    error_page 401 = @unauthorized;
    location @unauthorized {
        default_type application/json;
        return 401 '{"error":"Invalid or missing API key. Include X-API-Key header."}';
    }

    # API key validation
    location / {
        if (\$api_key_valid = 0) {
            return 401;
        }

        proxy_pass http://localhost:11434;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # For streaming responses
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding on;
        
        # Increase timeouts for long-running requests
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

# Enable the site
echo ""
echo "4️⃣  Enabling nginx site..."
ln -sf /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
echo ""
echo "5️⃣  Testing nginx configuration..."
nginx -t

# Restart nginx
echo ""
echo "6️⃣  Restarting nginx..."
systemctl restart nginx
systemctl enable nginx

# Configure Ollama to listen only on localhost
echo ""
echo "7️⃣  Configuring Ollama for localhost only..."
mkdir -p /etc/systemd/system/ollama.service.d

GFX_VERSION=$(rocminfo 2>/dev/null | grep -oP 'Name:\s+gfx\K[0-9]+' | head -1)
HSA_OVERRIDE_LINE=""

case "$GFX_VERSION" in
    1150|1151)
        HSA_OVERRIDE_LINE='Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"'
        ;;
esac

cat > /etc/systemd/system/ollama.service.d/remote.conf << EOF
[Service]
# Bind to localhost only (nginx will handle external access)
Environment="OLLAMA_HOST=127.0.0.1:11434"

# Apply machine-specific ROCm compatibility override only when needed
$HSA_OVERRIDE_LINE
EOF

systemctl daemon-reload
systemctl restart ollama

# Save API key to file
echo ""
echo "8️⃣  Saving API key..."
echo "$API_KEY" > /root/ollama_api_key.txt
chmod 600 /root/ollama_api_key.txt

echo ""
echo "========================================"
echo "✅ Setup Complete!"
echo "========================================"
echo ""
echo "📝 Configuration Summary:"
echo "   • Ollama: localhost:11434 (internal only)"
echo "   • Nginx proxy: *:8080 (external access)"
echo "   • API Key saved to: /root/ollama_api_key.txt"
echo ""
echo "🔑 Your API Key:"
echo "   $API_KEY"
echo ""
echo "🧪 Test with:"
echo "   curl -H \"X-API-Key: $API_KEY\" http://localhost:8080/api/version"
echo ""
echo "📖 Client examples in: ~/AMD_Ryzen_AI_395_Ubuntu/OLLAMA_SETUP.md"
echo ""
echo "⚠️  IMPORTANT: Save your API key securely!"
echo ""
