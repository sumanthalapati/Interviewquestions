# Security & Production Scenarios

Complete guide on security design, production incident response, deployment strategies, and handling real-world failure scenarios.

---

## Table of Contents
1. [Security Design Patterns](#security-patterns)
2. [Authentication & Authorization](#auth)
3. [Data Security](#data-security)
4. [API Security](#api-security)
5. [Production Incident Response](#incidents)
6. [Deployment Strategies](#deployment)
7. [Monitoring & Alerting](#monitoring)
8. [Disaster Recovery](#recovery)
9. [Common Failure Scenarios](#failures)
10. [Security Checklist](#security-checklist)

---

## Security Design Patterns {#security-patterns}

### Defense in Depth (Layered Security)

```
Attack surface has multiple barriers

Layer 1: Network Security
[DDoS Protection] → [WAF - Web Application Firewall]

Layer 2: Application Security
[Authentication] → [Authorization] → [Rate Limiting]

Layer 3: Data Security
[Encryption in transit] → [Encryption at rest] → [Data masking]

Layer 4: Operational Security
[Monitoring] → [Alerting] → [Audit logs]

Even if one layer breached, others protect
```

### Zero Trust Architecture

**Old Model** (Perimeter-based)
```
Inside network = trusted
Outside network = untrusted

Problem: If inside compromised (insider threat), everything at risk
```

**Zero Trust Model**
```
Nobody trusted by default
Every request verified (authentication, authorization)
Every component isolated

Example:
- User A requests resource → verify identity → verify has permission
- Even if user A is insider, access limited to specific resources
- System logs every access (audit trail)
```

### Principle of Least Privilege

**Definition**: User/service has minimum permissions needed for task

**Example: Database Credentials**
```
❌ Wrong: Single admin credential (user=admin, pass=admin123)
          - All apps use same credential
          - If credential leaked, all databases compromised
          - No way to identify which app leaked it

✅ Right: App-specific credentials
          - API service: SELECT-only on user_profiles table
          - Analytics service: SELECT on events table (read-only)
          - Batch processor: DELETE permission only on temp tables
          - If one credential leaked, exposure limited
          - Can identify which app was compromised
```

---

## Authentication & Authorization {#auth}

### Authentication Methods

**Password**
```
Pros: Simple, universal
Cons: Users reuse passwords, weak passwords, brute-force attacks

Best practice:
- Bcrypt/Scrypt (slow hash, resistant to GPU attacks)
- 12+ character minimum
- Rate limiting (5 failed attempts → wait 5 minutes)
- Optional 2FA/MFA
```

**OAuth 2.0** (Third-party login)
```
"Login with Google" flow

User clicks "Login with Google"
  ↓
Google login page (not your site)
  ↓
Google generates code
  ↓
Code sent to your app
  ↓
Your app exchanges code for access token
  ↓
Your app calls Google API to get user info
  ↓
Create local session

Pros: User controls permissions, no password stored
Cons: Dependent on third party, more complex
```

**JWT (JSON Web Token)**
```
Token structure: [header.payload.signature]

Example payload:
{
  "sub": "user_123",
  "email": "user@example.com",
  "role": "admin",
  "exp": 1234567890
}

Signed with secret key so can't be forged

Pros: Stateless (no server session storage needed), scalable
Cons: Token revocation hard (user logs out, but token still valid until expiry)
```

**MFA (Multi-Factor Authentication)**
```
2FA examples:
1. Password + OTP (one-time password) from authenticator app
2. Password + SMS code
3. Password + hardware key (YubiKey)
4. Biometric + password

Cost: More secure, more user friction
Use: Sensitive accounts (admin, financial)
```

### Authorization

**RBAC (Role-Based Access Control)**
```
Assign users to roles, roles have permissions

Example:
User john → admin role → permissions: [read_all, write_all, delete_user]
User jane → editor role → permissions: [read_own, write_own]
User bob → viewer role → permissions: [read_public]

Pros: Easy to manage, familiar
Cons: Inflexible (can't do "create documents in folder X only")
```

**ABAC (Attribute-Based Access Control)**
```
Fine-grained control based on attributes

Example:
Allow access if:
- User role = "editor"
- AND Document owner = current user
- AND Document status = "draft"
- AND Time is during business hours (9am-5pm)

Pros: Flexible, powerful
Cons: Complex to implement, hard to audit
```

### Session Management

**Stateful Sessions**
```
Server stores session
[Client] → login → [Server stores session in memory/Redis]
[Client] → request with session_id → [Server looks up session]

Pros: Can revoke immediately (logout invalidates session)
Cons: Server must store, doesn't scale horizontally
```

**Stateless Sessions (JWT)**
```
No server storage, token contains all info

[Client] → login → [Server generates JWT]
[Client] → request with JWT → [Server verifies JWT signature]

Pros: Scales horizontally, microservices friendly
Cons: Logout revocation delayed (token valid until expiry)
       Solution: Logout blacklist in cache (Revocation list)
```

---

## Data Security {#data-security}

### Encryption in Transit

**HTTPS (TLS)**
```
All traffic encrypted (prevent eavesdropping)

Setup:
1. Get SSL certificate (free from Let's Encrypt)
2. Configure server (install certificate)
3. Redirect HTTP → HTTPS
4. Enable HSTS (force HTTPS, prevent downgrade attack)

Cost: Minimal (Let's Encrypt free), massive security gain

Cipher suites (negotiate strongest):
- TLS 1.3 only (latest, fastest, most secure)
- TLS 1.2 minimum (if legacy support needed)
- Disable TLS 1.0, 1.1 (broken)
```

**VPN / Tunnel**
```
For internal communication (service-to-service)

Example: Database in private VPC, app in private subnet
Connection: encrypted tunnel, no exposure on internet

Cost: Low (built into cloud providers)
```

### Encryption at Rest

**Database Encryption**
```
Data encrypted on disk

Pros: Even if disk stolen, data unreadable
Cons: Minimal performance overhead (handled by storage layer)

Standard: Use AES-256

Implementation:
- SQL: RDS encryption enabled
- NoSQL: MongoDB, DynamoDB have built-in encryption
- File storage: S3 encryption, Azure storage encryption
```

**Key Management**
```
Problem: Where to store encryption key?

❌ Wrong: In code or config file (if code leaked, key leaked)
❌ Wrong: Same key everywhere (rotation nightmare)

✅ Right: Key management service (AWS KMS, Azure Key Vault)
          - Keys never exposed to application
          - Centralized rotation
          - Audit who accessed keys
          - Automatic key versioning
```

### Data Masking

**PII Protection** (Personally Identifiable Information)
```
Example: Credit card number 4111-1111-1111-1111

Logging: Log masked version "****-****-****-1111"
         → Doesn't reveal full card number
         → Still useful for debugging

Database: Show full to authorized (finance), masked to others

Implementation:
- Regex replace: 4111-1111-1111-1111 → ****-****-****-1111
- Tokenization: Actual card stored in separate secure vault
```

### Data Retention & Deletion

**GDPR Compliance** (Right to be forgotten)
```
User requests deletion of account

System must:
1. Delete from all databases
2. Delete backups (or wait for expiry)
3. Delete from analytics (or anonymize)
4. Delete from logs (or anonymize)
5. Verify deletion (sometimes third-party audit)

Cost: Significant (backups can't be deleted on whim)
       Solution: Implement account deletion policy (30-day wait)
```

---

## API Security {#api-security}

### Input Validation & Sanitization

**SQL Injection**
```
❌ Vulnerable:
String query = "SELECT * FROM users WHERE id = " + user_input;
// Input: " OR 1=1 --
// Result: SELECT * FROM users WHERE id =  OR 1=1 --
// Returns all users!

✅ Safe:
PreparedStatement stmt = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
stmt.setInt(1, user_input);
// Input treated as parameter, not code
```

**XSS (Cross-Site Scripting)**
```
❌ Vulnerable:
<div>User comment: <%= user_comment %></div>
// If comment = "<script>alert('hacked')</script>"
// Script executes in other users' browsers!

✅ Safe:
<div>User comment: <%= htmlEscape(user_comment) %></div>
// "<script>" becomes "&lt;script&gt;" (displayed as text)
```

**CSRF (Cross-Site Request Forgery)**
```
Attack:
1. You log into bank.com
2. Visit evil.com (secretly)
3. evil.com calls bank.com/transfer?amount=1000
4. Bank thinks you authorized (you're logged in)
5. Money transferred!

Prevention:
- CSRF token in every form
- Token checked on server (matches session)
- GET only for reads (POST for writes with token)
```

### Rate Limiting

**Purpose**: Prevent abuse (brute-force, DoS)

```
Implementation: Token bucket

Bucket capacity: 100 requests
Refill rate: 1 request per second

User makes 5 requests → 95 left in bucket
User waits 5 seconds → bucket refilled to 100

If user tries 200 requests → bucket empty after 100
  → Further requests rejected (429 Too Many Requests)
```

**Per-User vs Per-IP**
```
Per-IP rate limit:
- Stops anonymous attackers
- But penalizes office networks (same IP shared)

Per-User rate limit:
- Stops authenticated attackers
- Requires authentication (not all APIs require this)

Solution: Both (per-IP for unauthenticated, per-user for authenticated)
```

### API Key Management

**Secure Key Distribution**
```
❌ Wrong: Send key via email (email not encrypted, backups everywhere)
❌ Wrong: Generate once, hardcode in config (leaked in code)

✅ Right:
1. Generate key in API dashboard
2. User copies key immediately (shown once only)
3. Key stored only by user (no server backup)
4. Key sent as header or query param (encrypted by HTTPS)
5. Rotate key every 90 days
6. Revoke compromised keys immediately
```

---

## Production Incident Response {#incidents}

### Incident Severity Levels

**Sev 1 (Critical)**
```
Complete outage, revenue impact, security breach
Example: Database down, all users can't log in

Response time: Within 5 minutes
Resolution time: < 1 hour (or escalate to senior eng)

Actions:
1. Page on-call engineer (immediately)
2. Start war room (Slack channel, Zoom call)
3. Assign roles: Incident commander, technician, communicator
4. Start mitigation (not root cause yet)
5. Update status page every 15 minutes
6. Once resolved: Postmortem within 24 hours
```

**Sev 2 (High)**
```
Partial outage, some users affected, degraded performance
Example: Slow API (p99 latency 5x normal), 10% error rate

Response time: Within 30 minutes
Resolution time: < 4 hours

Actions:
1. Assign engineer (not necessarily on-call)
2. Investigate root cause
3. Implement fix or rollback
4. Monitor for recurrence
5. Schedule postmortem within 1 week
```

**Sev 3 (Medium)**
```
Minor issue, workaround available
Example: One feature buggy, users can use alternative

Response time: Within 2 hours
Resolution time: < 1 day

Actions:
1. Create ticket
2. Assign to engineer
3. Fix during normal work
4. Deploy in next release
```

**Sev 4 (Low)**
```
Cosmetic, user happiness issue
Example: Typo in error message, visual glitch

Resolution time: < 1 week (next release)
```

### Incident Response Playbook

**Phase 1: Detection (0-5 min)**
```
Monitoring alerts or user reports
- Alert triggered → Page on-call
- User reports → Triage (is it real? widespread?)
- Verify (can you reproduce?)
```

**Phase 2: Communication (Concurrent)**
```
- Slack notification to team
- Status page: "Investigating"
- Customer notification email (if outage)
- War room setup (Zoom call)

Do NOT:
- Speculate publicly ("probably load balancer")
- Over-promise timeline ("fixed in 10 minutes")
- Ignore users ("we're aware, working on it" every 5 min)
```

**Phase 3: Mitigation (5-30 min)**
```
Fastest fix, not best fix

Options (in order):
1. Rollback last deploy (if recent)
2. Kill bad requests (rate limit, block IPs)
3. Degrade gracefully (disable feature, use stale cache)
4. Scale up (add instances if traffic spike)
5. Restart service (if hung process)
6. Switch to backup (if primary failed)

Goal: Restore service even if root cause not found
```

**Phase 4: Root Cause Analysis (30 min - 2 hours)**
```
Debug: Logs, metrics, traces

Questions:
- When did it start?
- What changed recently? (deploys, config changes)
- Which component failed? (database, cache, API, external service)
- Why did monitoring miss it? (bad alert thresholds)
```

**Phase 5: Permanent Fix (Hours - Days)**
```
Implement proper fix:
- Code change (if bug)
- Config change (if misconfiguration)
- Capacity increase (if overloaded)
- Circuit breaker (if external service failing)

Test:
- Run in staging
- Verify fix (monitoring confirms issue resolved)
- Deploy (with gradual rollout if possible)
```

**Phase 6: Postmortem (Within 24 hours)**
```
Blameless culture (focus on systems, not people)

Document:
- Timeline (what happened when)
- Impact (users affected, revenue impact, duration)
- Root cause (why did this happen)
- Immediate actions (what we did to fix)
- Follow-up actions (prevent recurrence)
- Lessons learned

Example follow-ups:
- Add better monitoring
- Write runbook for this scenario
- Improve deploy process
- Add integration test
- Change alert thresholds
```

---

## Deployment Strategies {#deployment}

### Deployment Types

**Big Bang (All at Once)**
```
Old version → [Stop] → New version → [Start]

Pros: Simple, quick
Cons: High risk (any bug = full rollback), downtime

Use: Internal tools, low-traffic services
```

**Rolling Deployment**
```
v1 (10%) → v1 (20%) → v1 (30%) → v2 (10%) → v2 (30%) → ... → v2 (100%)

Process:
1. Stop 10% of servers
2. Deploy new version
3. Start servers
4. Monitor for errors
5. Repeat for next 10%

Pros: Zero downtime, errors caught early (only 10% affected)
Cons: Longer deploy time (30 min - 2 hours)
```

**Blue-Green Deployment**
```
Blue environment (current, v1)
Green environment (new, v2)

1. Deploy v2 to green (while blue serving traffic)
2. Test green thoroughly
3. Switch router to green (instant)
4. Keep blue as quick rollback

Pros: Instant rollback, zero downtime
Cons: 2x resources needed (two full environments)
```

**Canary Deployment**
```
v1 (99%) → v1 (95%) → v1 (90%) → ... → v2 (100%)

1. Deploy v2 to 1% of servers (canary)
2. Monitor metrics (latency, errors, success rate)
3. If good → increase to 10%
4. If bad → rollback canary immediately
5. Gradually ramp up (1% → 10% → 50% → 100%)

Pros: Early error detection, low impact
Cons: Slower (days possible), complex monitoring
```

### Rollback Strategy

**Automated Rollback**
```
If deploy causes:
- Error rate > 1% (was 0.05%)
- Latency p99 > 2x baseline
- Service unavailable (all instances down)

Automatically:
1. Stop new version
2. Kill new deployment
3. Restart old version
4. Alert team

Prevents human delay, minimizes impact
```

**Feature Flags**
```
Deploy code but disable feature

Benefits:
- Decouple deploy from feature release
- Dark launch (deploy without enabling)
- Gradual rollout (10% users get feature)
- Quick kill (flip flag, done)

Example:
if (featureFlags.newCheckout) {
  // New code (not executed if disabled)
} else {
  // Old code (used when feature disabled)
}
```

---

## Monitoring & Alerting {#monitoring}

### What to Monitor

**Metrics (Quantitative)**
```
- Latency (p50, p95, p99)
- Throughput (QPS, requests/sec)
- Error rate (failures ÷ total)
- Resource usage (CPU, memory, disk)
- Business metrics (revenue, signups, DAU)
```

**Logs (Detailed traces)**
```
Level 1 (ERROR): "Database connection failed: timeout after 30s"
Level 2 (WARN): "Slow query: 2s, expected < 500ms"
Level 3 (INFO): "User 123 logged in"
Level 4 (DEBUG): "Cache hit for key 'user:123'"

Aggregate: Search across thousands of servers
Correlate: If latency high, which logs appear?
```

**Traces (Request flow)**
```
Request path: Client → API → Database → Cache

Each hop logged:
API (5ms) → Database (20ms) → Cache (1ms) → Response (1ms)
Total: 27ms

If latency high: Which hop is slow?
Distributed tracing helps identify bottleneck
```

### Alert Guidelines

**Rule: Have few, high-quality alerts**

```
Bad: 1000 alerts/day (alert fatigue, miss real issues)
Good: 10 alerts/day, 90% actionable

Actionable alert:
- Specific (not "something is wrong")
- Severity clear (Sev 1, 2, 3)
- Runbook available (how to fix?)

Example good alert:
"Error rate > 1% for 5 minutes (was 0.05%)
Severity: 2
Runbook: Check recent deploys, review error logs"
```

### Alert Thresholds

**Start Conservative, Tighten Over Time**
```
Week 1: Alert if error rate > 5% (too high, but prevents false alarms)
Week 2: Alert if error rate > 2%
Week 3: Alert if error rate > 1%
Month 2: Alert if error rate > 0.1%

Goal: Find sweet spot (catches real issues, few false alarms)
```

---

## Disaster Recovery {#recovery}

### RTO & RPO

**RTO (Recovery Time Objective)**: How long can you be down?
```
Critical service: < 1 hour RTO
Important service: < 4 hours RTO
Nice-to-have service: < 1 day RTO

Strategy changes based on RTO:
RTO < 1 hour → Needs failover (hot backup)
RTO < 1 day → Needs restore from backup
```

**RPO (Recovery Point Objective)**: How much data can you lose?
```
Financial: RPO < 1 minute (frequent backups)
Social media: RPO < 1 hour (less critical)
Old logs: RPO < 1 day

Tradeoff: Smaller RPO = more backups = more cost
```

### Backup Strategy

**Backup Frequency**
```
Critical database:
- Full backup daily (nightly at 2am)
- Incremental every 1 hour (changes since last backup)
- Transaction log every 5 minutes

RPO: < 5 minutes (can restore to any 5-minute window)
```

**Backup Locations**
```
Same datacenter:
- Pros: Fast restore (< 1 hour)
- Cons: If datacenter destroyed, all backups gone

Different regions:
- Pros: Survives regional disaster
- Cons: Network transfer time, higher cost

Strategy:
- Primary: Local backup (fast recovery)
- Secondary: Cross-region backup (disaster recovery)
```

**Restore Testing**
```
Problem: Backup made, never tested
         When disaster hits, restore fails (surprise!)

Solution: Monthly restore test
- Actual production backup
- Restore to test environment
- Verify data integrity
- Measure restore time

Document:
- RTO actual (took 2 hours)
- RPO actual (5-minute gap after restore)
- Issues found (schema mismatch, large file issues)
```

### Failover Strategies

**Master-Slave Failover**
```
Master: Serving traffic
Slave: Replica (backup)

If master dies:
1. Detect (monitoring failure for 5 seconds)
2. Promote slave → new master
3. Update DNS (point to new master)
4. Old master comes back → becomes slave

Manual: 5-10 minutes
Automated: < 1 minute
```

**Active-Active**
```
Two datacenters both serving traffic
If one dies, traffic goes to other

Challenges:
- Consistency (both must agree)
- Split-brain (if network partitioned, both serve, causing duplicates)
- Failback (when original comes back, sync data)

Use: Only if RPO critical (financial)
```

---

## Common Failure Scenarios {#failures}

### Scenario 1: Database Goes Down

```
Impact: All requests fail (can't query database)
Severity: 1 (Critical)

Mitigation (minutes):
1. Switch to replica (if promoted)
2. Use read-only cache (serve cached data)
3. Graceful degradation (show "data unavailable" vs crash)

Root cause investigation:
- Out of disk space?
- Bad query locking table?
- Connection limit reached?
- Network partition?

Fix:
- Free disk space (delete old logs)
- Kill bad query
- Increase connection pool size
- Fix network

Prevention:
- Monitor disk usage (alert at 80%)
- Query timeout (kill queries > 30 seconds)
- Connection pooling
- Redundant network paths
```

### Scenario 2: Cache Layer Crashes

```
Impact: Cache misses → database queries spike
Result: Database overloaded, cascading failure

Mitigation:
1. Restart cache (fast if small data)
2. Rebuild cache (warm from database, slow)
3. Drop cache (use database temporarily, slower but works)

Prevention:
- Cache replication (if one crashes, replica available)
- Circuit breaker (if cache failing, skip cache, go direct to DB)
- Cache warming (pre-load on startup)
- Monitoring (alert if cache down)
```

### Scenario 3: External API Failing

```
Your service calls third-party API (payment processor, email service)

Impact: Your feature dependent on API broken

Mitigation:
1. Retry with backoff (transient failures)
2. Fallback (use old data or dummy response)
3. Degrade gracefully (show "feature unavailable")
4. Bulkhead (failure in API doesn't crash your service)

Prevention:
- Circuit breaker (stop calling after N failures)
- Timeout (don't wait forever)
- Fallback handler (what to do if API fails)
- SLA monitoring (API reliability < expected → alert)
```

### Scenario 4: Denial of Service (DoS)

```
Attacker sends massive requests, overwhelms service

Impact: Legitimate users can't access service

Mitigation:
1. DDoS protection (Cloudflare, AWS Shield)
2. Rate limiting (limit per IP)
3. WAF (block known attack patterns)
4. Scale up (add instances)
5. Shed load (reject low-priority requests)

Detection:
- Sudden traffic spike (10x normal)
- From limited IPs (suspicious)
- Same pattern (not organic)

Prevention:
- CAPTCHA (separate bots from users)
- Authentication (harder for attackers)
- Good monitoring (catch early)
```

---

## Security Checklist {#security-checklist}

### Before Launch

- [ ] HTTPS enabled (certificate valid, HSTS header)
- [ ] Passwords hashed (bcrypt, not MD5)
- [ ] Input validation (SQL injection, XSS tested)
- [ ] CSRF tokens on forms
- [ ] Rate limiting enabled
- [ ] Secrets not in code (environment variables)
- [ ] Encryption at rest for sensitive data
- [ ] Audit logging (who did what when)
- [ ] Error messages don't leak info ("Invalid username or password" not "User not found")
- [ ] Session timeout (30 min inactivity)
- [ ] CORS configured (if using cross-origin)
- [ ] Security headers (CSP, X-Frame-Options, etc.)

### Before Production

- [ ] Penetration testing (external contractor)
- [ ] Dependency scan (known vulnerabilities)
- [ ] Code review (security focus)
- [ ] Monitoring & alerting (detect attacks)
- [ ] Incident response plan (what if breached)
- [ ] Backup & restore tested
- [ ] DDoS protection enabled
- [ ] API keys rotated
- [ ] Secrets management (KMS, Vault)
- [ ] Documentation (runbooks, architecture)

### Ongoing

- [ ] Monthly dependency updates
- [ ] Quarterly penetration testing
- [ ] Rotation: API keys (quarterly), passwords (annually), certificates (annually)
- [ ] Monitoring alerts reviewed (tune for fewer false positives)
- [ ] Logs reviewed for suspicious activity
- [ ] Security patches applied immediately
- [ ] Team training (phishing awareness, secure coding)

---

**Key Takeaway**: Security is not a feature, it's a process. Bake it in from start, monitor constantly, and respond quickly to incidents.
