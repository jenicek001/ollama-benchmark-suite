# Ollama Remote Server Setup - AMD Ryzen AI 395

## 🎉 Installation Complete!

### System Configuration
- **Server IP**: `192.168.0.218`
- **Ollama API Port**: `11434`
- **Ollama Version**: `0.12.10`
- **GPU**: AMD Radeon 8060S (gfx1151) 
- **GPU Memory**: 96.0 GB available
- **Compute Library**: ROCm

---

## 📡 Remote Access Configuration

Ollama is configured as a systemd service and accepts connections from any network interface.

### Configuration File
Location: `/etc/systemd/system/ollama.service.d/remote.conf`

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
```

---

## 🔧 Service Management

### Check Status
```bash
systemctl status ollama
```

### Restart Service
```bash
sudo systemctl restart ollama
```

### View Logs
```bash
sudo journalctl -u ollama -f
```

### Stop/Start Service
```bash
sudo systemctl stop ollama
sudo systemctl start ollama
```

---

## 🌐 API Usage

### From Remote Machine

#### Test Connection
```bash
curl http://192.168.0.218:11434/api/version
```

#### List Available Models
```bash
curl http://192.168.0.218:11434/api/tags
```

#### Generate Text
```bash
curl http://192.168.0.218:11434/api/generate -d '{
  "model": "qwen2.5:0.5b",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

#### Chat Completion
```bash
curl http://192.168.0.218:11434/api/chat -d '{
  "model": "qwen2.5:0.5b",
  "messages": [
    {
      "role": "user",
      "content": "Hello, how are you?"
    }
  ],
  "stream": false
}'
```

### From Your Web Application

#### Python Example
```python
import requests

OLLAMA_URL = "http://192.168.0.218:11434"

# Check if Ollama is available
def check_ollama():
    try:
        response = requests.get(f"{OLLAMA_URL}/api/version")
        return response.status_code == 200
    except:
        return False

# Generate text
def generate(prompt, model="qwen2.5:0.5b"):
    response = requests.post(
        f"{OLLAMA_URL}/api/generate",
        json={
            "model": model,
            "prompt": prompt,
            "stream": False
        }
    )
    return response.json()["response"]

# Chat completion
def chat(messages, model="qwen2.5:0.5b"):
    response = requests.post(
        f"{OLLAMA_URL}/api/chat",
        json={
            "model": model,
            "messages": messages,
            "stream": False
        }
    )
    return response.json()["message"]["content"]
```

#### Node.js/TypeScript Example
```typescript
const OLLAMA_URL = "http://192.168.0.218:11434";

// Check if Ollama is available
async function checkOllama(): Promise<boolean> {
  try {
    const response = await fetch(`${OLLAMA_URL}/api/version`);
    return response.ok;
  } catch {
    return false;
  }
}

// Generate text
async function generate(prompt: string, model = "qwen2.5:0.5b"): Promise<string> {
  const response = await fetch(`${OLLAMA_URL}/api/generate`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ model, prompt, stream: false }),
  });
  const data = await response.json();
  return data.response;
}

// Chat completion
async function chat(messages: Array<{role: string, content: string}>, model = "qwen2.5:0.5b"): Promise<string> {
  const response = await fetch(`${OLLAMA_URL}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ model, messages, stream: false }),
  });
  const data = await response.json();
  return data.message.content;
}
```

---

## 📦 Model Management

### Pull a Model
```bash
ollama pull llama3.1:8b
ollama pull qwen2.5:7b
ollama pull mistral:7b
```

### List Downloaded Models
```bash
ollama list
```

### Remove a Model
```bash
ollama rm model_name
```

---

## 🔄 Updating Ollama

Ollama installed via the official script can be updated easily:

```bash
# Download and run the install script again
curl -fsSL https://ollama.com/install.sh | sh

# Restart the service
sudo systemctl restart ollama
```

The script will:
- ✅ Detect existing installation
- ✅ Preserve your configuration
- ✅ Keep your models
- ✅ Update to the latest version

---

## 🔒 Security Considerations

### Current Setup
- ⚠️ **No authentication** - API is open to anyone who can reach the server
- ⚠️ **No firewall rules** - Port 11434 is accessible from any IP

### Recommended for Production

#### 1. Enable UFW Firewall (Allow specific IPs only)
```bash
# Enable firewall
sudo ufw enable

# Allow SSH first!
sudo ufw allow 22/tcp

# Allow Ollama only from your web server
sudo ufw allow from YOUR_WEB_SERVER_IP to any port 11434

# Or allow from your local network
sudo ufw allow from 192.168.0.0/24 to any port 11434
```

#### 2. Use Reverse Proxy with API Key Authentication (Recommended)

**Option A: Nginx with API Key Header**

Install nginx:
```bash
sudo apt install nginx
```

Create nginx configuration `/etc/nginx/sites-available/ollama`:
```nginx
# Map to check API key
map $http_x_api_key $api_key_valid {
    default 0;
    "your-secret-api-key-here" 1;
    "another-valid-key-here" 1;
}

server {
    listen 8080;
    server_name _;

    # API key validation
    location / {
        if ($api_key_valid = 0) {
            return 401 '{"error":"Invalid or missing API key"}';
        }

        proxy_pass http://localhost:11434;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # For streaming responses
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding on;
    }
}
```

Enable and restart:
```bash
sudo ln -s /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

Configure Ollama to listen only on localhost:
```bash
sudo nano /etc/systemd/system/ollama.service.d/remote.conf
# Change: Environment="OLLAMA_HOST=127.0.0.1:11434"
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Now clients must use API key:
```bash
# With API key
curl -H "X-API-Key: your-secret-api-key-here" http://192.168.0.218:8080/api/version

# Without API key (will fail)
curl http://192.168.0.218:8080/api/version
```

**Option B: Caddy with API Key (Simpler)**

Install Caddy:
```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

Create Caddyfile `/etc/caddy/Caddyfile`:
```
:8080 {
    @authorized {
        header X-API-Key "your-secret-api-key-here"
    }

    handle @authorized {
        reverse_proxy localhost:11434
    }

    respond "Unauthorized - Invalid or missing API key" 401
}
```

Restart Caddy:
```bash
sudo systemctl restart caddy
```

**Option C: Python Middleware (For Development)**

Create a simple proxy with API key validation:

```python
# save as ollama_proxy.py
from flask import Flask, request, Response
import requests

app = Flask(__name__)

VALID_API_KEYS = {
    "your-api-key-1",
    "your-api-key-2",
}
OLLAMA_URL = "http://localhost:11434"

def check_api_key():
    api_key = request.headers.get('X-API-Key')
    return api_key in VALID_API_KEYS

@app.before_request
def validate_api_key():
    if not check_api_key():
        return {"error": "Invalid or missing API key"}, 401

@app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def proxy(path):
    resp = requests.request(
        method=request.method,
        url=f"{OLLAMA_URL}/{path}",
        headers={k: v for k, v in request.headers if k != 'Host'},
        data=request.get_data(),
        stream=True,
    )
    
    return Response(
        resp.iter_content(chunk_size=1024),
        status=resp.status_code,
        headers=dict(resp.headers)
    )

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

Install and run:
```bash
pip install flask requests
python3 ollama_proxy.py
```

**Client Usage Examples:**

Python:
```python
import requests

OLLAMA_URL = "http://192.168.0.218:8080"
API_KEY = "your-secret-api-key-here"

headers = {"X-API-Key": API_KEY}

# Check version
response = requests.get(f"{OLLAMA_URL}/api/version", headers=headers)
print(response.json())

# Generate text
response = requests.post(
    f"{OLLAMA_URL}/api/generate",
    headers=headers,
    json={"model": "qwen2.5:0.5b", "prompt": "Hello!", "stream": False}
)
print(response.json()["response"])
```

Node.js/TypeScript:
```typescript
const OLLAMA_URL = "http://192.168.0.218:8080";
const API_KEY = "your-secret-api-key-here";

const headers = {
  "Content-Type": "application/json",
  "X-API-Key": API_KEY,
};

// Check version
const response = await fetch(`${OLLAMA_URL}/api/version`, { headers });
console.log(await response.json());

// Generate text
const genResponse = await fetch(`${OLLAMA_URL}/api/generate`, {
  method: "POST",
  headers,
  body: JSON.stringify({ 
    model: "qwen2.5:0.5b", 
    prompt: "Hello!", 
    stream: false 
  }),
});
console.log((await genResponse.json()).response);
```

#### 3. Basic Authentication (Alternative)
Install nginx and add basic auth:
```bash
sudo apt install nginx apache2-utils

# Create password file
sudo htpasswd -c /etc/nginx/.htpasswd api_user

# Configure nginx as reverse proxy with basic auth
```

#### 4. Use VPN or SSH Tunnel
For maximum security, don't expose Ollama directly.

**SSH Tunnel Example:**
```bash
# On client machine, create tunnel to Ollama server
ssh -L 11434:localhost:11434 honzik@192.168.0.218

# Then access Ollama via localhost
curl http://localhost:11434/api/version
```

---

## � Quick API Key Setup

**Automated Setup (Recommended):**
```bash
sudo ./setup_api_key.sh
```

This script will:
- ✅ Install and configure nginx with API key validation
- ✅ Generate a secure random API key
- ✅ Configure Ollama to listen on localhost only
- ✅ Set up nginx on port 8080 for external access
- ✅ Save your API key to `/root/ollama_api_key.txt`

After setup, clients must include the API key header:
```bash
curl -H "X-API-Key: YOUR_KEY_HERE" http://192.168.0.218:8080/api/version
```

See the **Security Considerations** section above for manual setup options and alternatives.

---

## �📊 Monitoring GPU Usage

### Check GPU Utilization
```bash
watch -n 1 rocm-smi
```

### View Ollama Logs with GPU Info
```bash
sudo journalctl -u ollama -f | grep "inference compute"
```

---

## 🐛 Troubleshooting

### Ollama Not Responding
```bash
sudo systemctl restart ollama
sudo journalctl -u ollama -n 50
```

### GPU Not Detected
```bash
# Check ROCm
rocminfo

# Check GPU driver
sudo dmesg | grep amdgpu

# Restart with debug logging
sudo systemctl edit ollama
# Add: Environment="OLLAMA_DEBUG=1"
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### Connection Refused from Remote
```bash
# Check if listening on all interfaces
sudo ss -tlnp | grep 11434

# Should show: *:11434 (not 127.0.0.1:11434)
```

---

## 🚀 Performance Testing

### Small Model (0.5B - Qwen2.5)
- **Load Time**: ~2 seconds
- **Prompt Eval**: ~1472 tokens/s
- **Generation**: ~311 tokens/s

### Recommended Models for 96GB VRAM
- **Small (< 1GB)**: qwen2.5:0.5b, tinyllama
- **Medium (4-8GB)**: llama3.1:8b, qwen2.5:7b, mistral:7b
- **Large (13-20GB)**: llama3.1:70b-q4, qwen2.5:32b
- **Extra Large (40-80GB)**: llama3.1:70b, qwen2.5:72b

You can run models up to ~90GB with your available VRAM!

---

## 📚 Additional Resources

- **Ollama Documentation**: https://github.com/ollama/ollama/tree/main/docs
- **API Reference**: https://github.com/ollama/ollama/blob/main/docs/api.md
- **Model Library**: https://ollama.com/library
- **ROCm Documentation**: https://rocm.docs.amd.com/

---

## ✅ Quick Health Check Script

Save as `check_ollama.sh`:
```bash
#!/bin/bash
echo "🔍 Checking Ollama Service..."
systemctl is-active --quiet ollama && echo "✅ Service: Running" || echo "❌ Service: Stopped"

echo ""
echo "🌐 Testing API..."
curl -s http://localhost:11434/api/version > /dev/null && echo "✅ API: Responding" || echo "❌ API: Not responding"

echo ""
echo "🎮 GPU Status:"
rocm-smi --showuse 2>/dev/null | grep -A 5 "GPU"

echo ""
echo "📦 Downloaded Models:"
ollama list
```

Make it executable: `chmod +x check_ollama.sh`
