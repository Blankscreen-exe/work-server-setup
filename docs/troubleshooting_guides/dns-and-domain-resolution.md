# DNS & Domain Resolution Troubleshooting

## Symptom: `DNS_PROBE_FINISHED_NXDOMAIN` or "Name resolution failed"

The browser or system cannot resolve the domain name, even though DNS records have been added.

### Step 1: Verify DNS records exist at the registrar

Confirm that A records are properly configured in your domain registrar's DNS panel. Each subdomain should have an A record pointing to the server IP.

Example:
| Type     | Host           | Value           |
|----------|----------------|-----------------|
| A Record | n8n-internal   | 84.46.244.158   |
| A Record | taiga          | 84.46.244.158   |

### Step 2: Check if DNS resolves from the server

```bash
dig <subdomain>.dev-in-trenches.com +short
```

If this returns the correct IP, the record is live.

### Step 3: Check if DNS resolves via public DNS (Google)

From your local machine (PowerShell):
```powershell
nslookup <subdomain>.dev-in-trenches.com 8.8.8.8
```

Or from the server:
```bash
dig <subdomain>.dev-in-trenches.com @8.8.8.8 +short
```

- If this **works** but your browser still fails, your local/ISP DNS has cached a stale negative response. See Step 4.
- If this **also fails**, the DNS record hasn't propagated yet. Wait and retry (can take minutes to hours).

### Step 4: Fix local DNS cache issues

#### Flush Windows DNS cache
```powershell
ipconfig /flushdns
```

#### Clear browser DNS cache (Chrome)
1. Navigate to `chrome://net-internals/#dns`
2. Click **Clear host cache**

#### Try incognito/private browsing mode

Open the URL in a private window to bypass browser-level caches.

#### Switch to Google DNS (if ISP DNS is slow to update)
1. Go to **Settings > Network & Internet > your connection > DNS**
2. Set manual DNS:
   - Primary: `8.8.8.8`
   - Secondary: `8.8.4.4`

This bypasses your ISP's DNS resolver, which may cache negative responses for longer.

---

## Symptom: DNS resolves but site is unreachable

### Check if the port is open on the server

```bash
# Test port 80
curl -v http://localhost

# Test port 443
curl -vk https://localhost
```

### Check if Traefik is routing the domain

```bash
curl -H "Host: <subdomain>.dev-in-trenches.com" http://localhost
```

- `Found` or a redirect response = Traefik is routing correctly
- `404` = Traefik doesn't have a matching router for that host

### Test from your local machine

PowerShell:
```powershell
Test-NetConnection -ComputerName <subdomain>.dev-in-trenches.com -Port 443
```

If `TcpTestSucceeded` is `False`, the port may be blocked by a firewall.
