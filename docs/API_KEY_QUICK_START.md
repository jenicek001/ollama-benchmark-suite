# Quick Reference - Ollama API Key Setup

## 🚀 One-Command Setup

```bash
sudo ./setup_api_key.sh
```

This will set up nginx as a reverse proxy with API key authentication.

---

## 📍 Before Setup

- **Current Access**: `http://192.168.0.218:11434` (no authentication)
- **Security**: ⚠️ Open to anyone on the network

## 📍 After Setup

- **External Access**: `http://192.168.0.218:8080` (requires API key)
- **Internal Access**: `http://localhost:11434` (no key needed, localhost only)
- **Security**: ✅ Protected with API key

---

## 🔑 Using Your API Key

### With curl:
```bash
curl -H "X-API-Key: YOUR_API_KEY" http://192.168.0.218:8080/api/version
```

### Python:
```python
import requests

headers = {"X-API-Key": "YOUR_API_KEY"}
response = requests.get("http://192.168.0.218:8080/api/version", headers=headers)
```

### Node.js:
```javascript
const headers = { "X-API-Key": "YOUR_API_KEY" };
const response = await fetch("http://192.168.0.218:8080/api/version", { headers });
```

---

## 🔧 Management Commands

### View your API key:
```bash
sudo cat /root/ollama_api_key.txt
```

### Add another API key:
```bash
sudo nano /etc/nginx/sites-available/ollama
# Add another line in the map section:
#   "new-api-key-here" 1;
sudo nginx -t
sudo systemctl reload nginx
```

### Check nginx status:
```bash
sudo systemctl status nginx
```

### View nginx logs:
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Test without API key (should fail):
```bash
curl http://192.168.0.218:8080/api/version
# Expected: {"error":"Invalid or missing API key. Include X-API-Key header."}
```

---

## 📊 Architecture After Setup

```
[Your Web App] 
    ↓ (with X-API-Key header)
[nginx :8080] → validates API key
    ↓ (if valid)
[Ollama :11434] → localhost only
    ↓
[AMD GPU - 96GB VRAM]
```

---

## 🔄 Reverting to No Authentication

If you want to remove API key authentication:

```bash
# Remove nginx site
sudo rm /etc/nginx/sites-enabled/ollama
sudo systemctl restart nginx

# Configure Ollama for external access again
sudo nano /etc/systemd/system/ollama.service.d/remote.conf
# Change back to: Environment="OLLAMA_HOST=0.0.0.0:11434"
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

## 📚 Full Documentation

See `OLLAMA_SETUP.md` for complete details including:
- Multiple authentication options (Caddy, Python middleware)
- API usage examples
- Model management
- Troubleshooting
- Performance tuning
