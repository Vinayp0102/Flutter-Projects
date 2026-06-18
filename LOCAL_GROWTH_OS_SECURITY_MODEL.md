# Local Growth OS - Security Model

## Overview

This document defines the comprehensive security architecture for Local Growth OS, covering authentication, authorization, data protection, compliance, and operational security.

---

## 1. Security Principles

### Core Tenets
1. **Defense in Depth:** Multiple layers of security controls
2. **Least Privilege:** Users and systems have minimum necessary access
3. **Zero Trust:** Never trust, always verify
4. **Privacy by Design:** Data protection built into architecture
5. **Audit Everything:** All actions logged and traceable
6. **Secure Defaults:** Safe configuration out of the box

---

## 2. Authentication Architecture

### 2.1 Authentication Providers

**Primary: Supabase Auth (PostgreSQL-based)**
- JWT token-based authentication
- Secure session management
- Built-in rate limiting
- Password hashing with bcrypt (cost factor 12)

**Enterprise Options (Phase 2+):**
- SAML 2.0 SSO (Okta, Azure AD, OneLogin)
- OAuth 2.0 (Google Workspace, Microsoft 365)
- LDAP integration

### 2.2 Authentication Flow

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Client    │      │  Supabase    │      │  Local      │
│  (Browser/  │      │     Auth     │      │  Growth OS  │
│   Mobile)   │      │              │      │  Backend    │
└──────┬──────┘      └──────┬───────┘      └──────┬──────┘
       │                    │                      │
       │  1. Login Request  │                      │
       │───────────────────>│                      │
       │                    │                      │
       │  2. Validate Creds │                      │
       │     Hash Password  │                      │
       │     Check MFA      │                      │
       │                    │                      │
       │  3. Issue JWT      │                      │
       │<───────────────────│                      │
       │                    │                      │
       │  4. API Request + JWT                     │
       │──────────────────────────────────────────>│
       │                    │                      │
       │                    │         5. Verify JWT│
       │                    │            Check Sig │
       │                    │            Check Exp │
       │                    │            Check RLS │
       │                    │                      │
       │  6. Response       │                      │
       │<───────────────────────────────────────────│
       │                    │                      │
```

### 2.3 JWT Token Structure

```json
{
  "iss": "https://auth.localgrowthos.com",
  "sub": "user-uuid",
  "aud": "local-growth-os-api",
  "exp": 1234567890,
  "iat": 1234567800,
  "tenant_id": "tenant-uuid",
  "role": "admin",
  "permissions": ["leads:read", "leads:write", "workflows:read"],
  "locations": ["location-uuid-1", "location-uuid-2"],
  "mfa_verified": true,
  "session_id": "session-uuid"
}
```

### 2.4 Multi-Factor Authentication (MFA)

**Supported Methods:**
- TOTP (Time-based One-Time Password) - Google Authenticator, Authy
- SMS OTP (fallback, less secure)
- Email OTP (fallback)
- WebAuthn/FIDO2 (Phase 2 - hardware keys, biometrics)

**MFA Policy:**
- Required for: Admin roles, Enterprise tenants
- Optional for: Other roles (encouraged)
- Recovery codes: Generated at MFA setup, stored encrypted

**MFA Flow:**
```
1. User enters username/password
2. System validates credentials
3. If MFA enabled → Challenge for MFA code
4. User provides TOTP/SMS code
5. System verifies code (time window ±30s)
6. Issue JWT with mfa_verified=true
```

### 2.5 Session Management

**Session Controls:**
- Maximum session duration: 30 days (configurable)
- Idle timeout: 2 hours of inactivity
- Concurrent sessions: Limited by plan (Starter: 3, Pro: 10, Business: unlimited)
- Session rotation on privilege changes

**Session Storage:**
- Active sessions tracked in Redis
- Session metadata in PostgreSQL (profiles table)
- Immediate invalidation on password change

---

## 3. Authorization Model

### 3.1 Role-Based Access Control (RBAC)

**Pre-defined Roles:**

| Role | Description | Permissions |
|------|-------------|-------------|
| **Owner** | Account owner, full access | All permissions, billing, tenant settings |
| **Admin** | Administrative access | All except billing/tenant deletion |
| **Manager** | Team management | Leads, contacts, team oversight, reports |
| **Agent** | Sales/service agent | Assigned leads, communications, appointments |
| **Front Desk** | Reception/administrative | Appointments, basic communications |
| **Read Only** | View-only access | Read-only on permitted resources |

**Permission Granularity:**
```
Resource:Verb format
Examples:
- leads:read, leads:write, leads:delete
- contacts:read, contacts:write
- workflows:read, workflows:write, workflows:execute
- reviews:read, reviews:respond
- reports:read, reports:export
- billing:read, billing:write
- settings:read, settings:write
- team:read, team:write, team:invite
```

### 3.2 Row-Level Security (RLS)

**Implementation via Supabase RLS:**

```sql
-- Example: Contacts table RLS
CREATE POLICY "tenant_isolation" ON contacts
  FOR ALL
  USING (
    tenant_id = current_setting('app.current_tenant')::uuid
  );

CREATE POLICY "role_based_access" ON contacts
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = contacts.tenant_id
      AND profiles.role IN ('owner', 'admin', 'manager', 'agent')
    )
  );

CREATE POLICY "assignment_based_access" ON contacts
  FOR SELECT
  USING (
    assigned_to = auth.uid() 
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('owner', 'admin', 'manager')
    )
  );
```

### 3.3 Location-Based Access Control

For multi-location businesses:

```json
{
  "user_id": "uuid",
  "role": "agent",
  "locations": ["loc-1", "loc-2"],
  "can_access_all_data": false
}
```

**Access Rules:**
- Users can only see data from assigned locations
- Managers/Admins can optionally have cross-location access
- Location filtering applied at query level via RLS

### 3.4 Attribute-Based Access Control (ABAC)

Advanced policies based on attributes:

```javascript
// Example policy evaluation
{
  "effect": "allow",
  "conditions": {
    "resource": "contact",
    "action": "update",
    "attributes": {
      "contact.assigned_to": "${user.id}",
      "contact.status": ["new", "contacted", "qualified"],
      "user.role": ["agent", "manager", "admin"],
      "time.hours": [9, 17] // Business hours only
    }
  }
}
```

---

## 4. Data Protection

### 4.1 Encryption

**Encryption at Rest:**
- Database: AES-256 encryption (Supabase managed)
- File storage: Server-side encryption (S3 SSE-S3 or SSE-KMS)
- Backups: Encrypted with separate keys
- Keys managed via AWS KMS or equivalent

**Encryption in Transit:**
- TLS 1.3 for all HTTP traffic
- HSTS enabled (Strict-Transport-Security header)
- Certificate pinning for mobile apps
- Perfect Forward Secrecy (PFS) ciphers only

**Field-Level Encryption:**
Sensitive fields encrypted individually:
- Phone numbers (for SMS providers)
- Access tokens (OAuth, API integrations)
- Payment information (handled by Stripe, not stored)

```sql
-- Example: Encrypt sensitive data
UPDATE review_platforms
SET access_token = pgp_sym_encrypt(${token}, ${encryption_key})
WHERE id = ${id};
```

### 4.2 Data Classification

| Classification | Examples | Handling Requirements |
|----------------|----------|----------------------|
| **Public** | Marketing content, public profiles | No special handling |
| **Internal** | Business settings, templates | Tenant isolation |
| **Confidential** | Lead data, contact info | Encryption, access logging |
| **Restricted** | Authentication tokens, PII | Field-level encryption, strict access |

### 4.3 Personal Identifiable Information (PII) Protection

**PII Categories:**
- Direct identifiers: Name, email, phone
- Indirect identifiers: Address, company
- Sensitive PII: Not collected (health, financial, etc.)

**PII Safeguards:**
- Minimization: Only collect necessary data
- Purpose limitation: Use only for stated purposes
- Retention limits: Delete after account closure + 90 days
- Right to access: Export all user data on request
- Right to deletion: Complete erasure on request (GDPR)
- Data portability: Standard formats (JSON, CSV)

### 4.4 Data Residency

**Options:**
- Default: US region (AWS us-east-1)
- EU option: AWS eu-west-1 (for GDPR compliance)
- Future: APAC region (AWS ap-southeast-1)

**Data Sovereignty:**
- Customer data never leaves chosen region
- Backups within same geographic boundary
- Subprocessors committed to same restrictions

---

## 5. API Security

### 5.1 API Authentication

**Methods:**
1. **JWT Bearer Token** (primary)
   ```
   Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
   ```

2. **API Keys** (for integrations)
   ```
   X-API-Key: lgos_live_xxxxxxxx
   ```
   - Prefix identifies key type (test/live)
   - Scoped permissions
   - Rate limited separately

3. **Webhook Signatures** (for inbound webhooks)
   ```
   X-Webhook-Signature: sha256=abcdef...
   ```

### 5.2 Rate Limiting

**Limits by Plan:**

| Plan | API Calls/min | SMS/day | Emails/day |
|------|---------------|---------|------------|
| Starter | 100 | 500 | 1,000 |
| Professional | 500 | 5,000 | 10,000 |
| Business | 2,000 | 25,000 | 50,000 |
| Enterprise | Custom | Custom | Custom |

**Implementation:**
- Redis-based sliding window counters
- Headers returned: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- Graceful degradation: Queue requests vs hard fail

### 5.3 Input Validation & Sanitization

**Validation Rules:**
- Schema validation on all inputs (Zod/JSON Schema)
- Type checking (string, number, boolean, enum)
- Length limits (prevent DoS via large payloads)
- Format validation (email, phone, URL)
- SQL injection prevention (parameterized queries)
- XSS prevention (output encoding)

**Example Validation:**
```typescript
const leadSchema = z.object({
  first_name: z.string().min(1).max(100),
  last_name: z.string().min(1).max(100),
  email: z.string().email().optional(),
  phone: z.string().regex(/^\+?[1-9]\d{1,14}$/).optional(),
  source: z.enum(['website', 'facebook', 'google', 'walk_in', 'phone']),
});
```

### 5.4 CORS Configuration

**Allowed Origins:**
- Production: `https://app.localgrowthos.com`
- Custom domains: Per-tenant configuration
- API consumers: Explicit allowlist

**CORS Headers:**
```
Access-Control-Allow-Origin: https://app.localgrowthos.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-API-Key
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 86400
```

---

## 6. Compliance Framework

### 6.1 GDPR Compliance (EU)

**Requirements Met:**
- ✅ Lawful basis for processing (contract performance)
- ✅ Privacy notices provided
- ✅ Data subject rights implemented:
  - Right to access (data export)
  - Right to rectification (profile editing)
  - Right to erasure (account deletion)
  - Right to restrict processing
  - Right to data portability
  - Right to object
- ✅ Data Processing Agreements (DPA) with subprocessors
- ✅ EU data residency option
- ✅ Data Protection Officer designated

**Data Processing Record:**
```
Controller: Customer (business using platform)
Processor: Local Growth OS
Categories: Contact data, communication records, business data
Purpose: CRM and marketing automation
Retention: Account lifetime + 90 days
```

### 6.2 CCPA Compliance (California)

**Requirements Met:**
- ✅ Notice at collection
- ✅ Right to know (disclosure of data practices)
- ✅ Right to delete
- ✅ Right to opt-out of sale (no data sold)
- ✅ Non-discrimination for exercising rights
- ✅ "Do Not Sell My Personal Information" link (not applicable but provided)

### 6.3 TCPA Compliance (SMS/Calling)

**Requirements Met:**
- ✅ Prior express written consent captured
- ✅ Clear disclosure of message frequency
- ✅ Opt-out mechanism (STOP keyword)
- ✅ Help mechanism (HELP keyword)
- ✅ Quiet hours respected (8am-9pm recipient timezone)
- ✅ Consent records maintained (audit trail)

**Consent Capture:**
```html
<input type="checkbox" required>
I agree to receive automated messages from [Business Name] 
at this phone number. Consent is not a condition of purchase.
Msg&Data rates may apply. Msg frequency varies. 
Text STOP to cancel, HELP for help.
</input>
```

### 6.4 CAN-SPAM / CASL Compliance (Email)

**Requirements Met:**
- ✅ Accurate header information
- ✅ Non-deceptive subject lines
- ✅ Clear identification as advertisement
- ✅ Physical address included
- ✅ Unsubscribe mechanism (one-click)
- ✅ Unsubscribe processed within 10 days
- ✅ Consent records (CASL)

### 6.5 Future Certifications (Roadmap)

**SOC 2 Type II (Year 2):**
- Security
- Availability
- Confidentiality
- Privacy

**HIPAA (Optional, Clinics):**
- Business Associate Agreement (BAA)
- Enhanced encryption
- Audit logging
- Access controls
- Not storing PHI (only appointment data)

---

## 7. Operational Security

### 7.1 Infrastructure Security

**Cloud Provider (AWS):**
- VPC isolation
- Private subnets for databases
- Security groups (firewall rules)
- WAF (Web Application Firewall)
- DDoS protection (AWS Shield)
- GuardDuty for threat detection

**Network Security:**
- No direct database internet access
- Bastion hosts for admin access
- VPN for internal tools
- PrivateLink for service connections

### 7.2 Application Security

**Secure Development:**
- OWASP Top 10 training for developers
- Code review requirements
- Static analysis (SAST) in CI/CD
- Dynamic analysis (DAST) before deployment
- Dependency scanning (SCA)
- Secret scanning (prevent credential leaks)

**Vulnerability Management:**
- Monthly security scans
- Quarterly penetration testing
- Bug bounty program (Phase 2)
- 24-hour critical patch SLA
- Coordinated disclosure policy

### 7.3 Logging & Monitoring

**Security Events Logged:**
- Authentication (success/failure)
- Authorization failures
- Password changes
- MFA changes
- API key creation/revocation
- Permission changes
- Data exports
- Bulk operations
- Administrative actions

**Log Storage:**
- Immutable logs (write-once)
- Retention: 1 year minimum
- Encrypted at rest
- Separate from application data
- SIEM integration (Splunk, Datadog)

**Alerting:**
- Failed login attempts (>5 in 5 minutes)
- Unusual API usage patterns
- Data exfiltration indicators
- Privilege escalation attempts
- Configuration changes
- Service disruptions

### 7.4 Incident Response

**Incident Classification:**

| Severity | Description | Response Time | Notification |
|----------|-------------|---------------|--------------|
| **P1 - Critical** | Active breach, data exposure | 15 minutes | Immediate to affected |
| **P2 - High** | Vulnerability exploited, no data loss | 1 hour | Within 24 hours |
| **P3 - Medium** | Security control failure | 4 hours | As needed |
| **P4 - Low** | Policy violation, minor issue | 24 hours | Internal only |

**Incident Response Process:**
1. Detection & Classification
2. Containment (isolate affected systems)
3. Eradication (remove threat)
4. Recovery (restore services)
5. Post-Incident Review (lessons learned)
6. Notification (if required by law/contract)

**Breach Notification:**
- GDPR: 72 hours to supervisory authority
- CCPA: "Most expedient time possible"
- Affected individuals: Without unreasonable delay

### 7.5 Backup & Disaster Recovery

**Backup Strategy:**
- Database: Continuous WAL archiving + daily snapshots
- Files: S3 versioning + cross-region replication
- Configuration: Git version control
- Secrets: Encrypted backup in separate system

**Recovery Objectives:**
- RTO (Recovery Time Objective): 4 hours
- RPO (Recovery Point Objective): 1 hour

**Disaster Recovery:**
- Multi-AZ deployment (primary)
- Cross-region backup (secondary)
- Documented runbooks
- Annual DR testing

---

## 8. Third-Party Security

### 8.1 Subprocessor Management

**Current Subprocessors:**

| Service | Purpose | Data Shared | Location |
|---------|---------|-------------|----------|
| Supabase | Database, Auth | All application data | US/EU |
| Twilio | SMS | Phone numbers, message content | Global |
| SendGrid | Email | Email addresses, content | Global |
| Stripe | Payments | Billing info (we don't store CC) | Global |
| AWS | Hosting | All data | US/EU |
| Google | GMB API | Review data | Global |
| Meta | Facebook API | Lead/review data | Global |

**Subprocessor Requirements:**
- Signed DPA (Data Processing Agreement)
- SOC 2 or equivalent certification
- Equivalent security standards
- Breach notification obligations
- Audit rights

### 8.2 API Integration Security

**Outbound Webhooks:**
- HTTPS only
- Signature verification (HMAC-SHA256)
- Retry with exponential backoff
- Timeout: 30 seconds
- Payload encryption option

**Inbound Integrations:**
- OAuth 2.0 where available
- API key rotation policy
- Scoped permissions
- Activity logging

---

## 9. Security Training & Awareness

### 9.1 Employee Training

**Requirements:**
- Annual security awareness training
- Role-specific training (developers, support, admins)
- Phishing simulation exercises (quarterly)
- Incident response drills (annual)

**Topics Covered:**
- Data handling procedures
- Password security
- Social engineering recognition
- Incident reporting
- Compliance requirements

### 9.2 Customer Security Guidance

**Documentation Provided:**
- Security best practices guide
- MFA setup instructions
- API security guidelines
- Data export/deletion procedures
- Compliance documentation (DPA, SCCs)

---

## 10. Security Metrics & KPIs

### 10.1 Operational Metrics

| Metric | Target | Frequency |
|--------|--------|-----------|
| Mean Time to Detect (MTTD) | < 1 hour | Monthly |
| Mean Time to Respond (MTTR) | < 4 hours | Monthly |
| Patch Deployment Time (Critical) | < 24 hours | Per incident |
| Failed Login Rate | < 5% | Daily |
| MFA Adoption Rate | > 80% | Monthly |
| Security Training Completion | 100% | Quarterly |

### 10.2 Compliance Metrics

| Metric | Target | Frequency |
|--------|--------|-----------|
| Data Subject Requests Fulfilled | 100% within 30 days | Monthly |
| DPA Coverage (Subprocessors) | 100% | Quarterly |
| Penetration Tests | 1 per year | Annual |
| SOC 2 Audit (when applicable) | Pass with no exceptions | Annual |
| Privacy Impact Assessments | 100% of new features | Per feature |

---

## 11. Security Roadmap

### Phase 1 (MVP - Months 1-4)
- ✅ Supabase Auth implementation
- ✅ RLS policies
- ✅ TLS everywhere
- ✅ Basic audit logging
- ✅ GDPR/CCPA compliance foundation
- ✅ TCPA-compliant SMS

### Phase 2 (Growth - Months 5-8)
- MFA enforcement for admins
- Enhanced API rate limiting
- Webhook signature verification
- Automated vulnerability scanning
- Bug bounty program launch
- DPA template completion

### Phase 3 (Scale - Months 9-12)
- SSO/SAML integration
- Advanced threat detection
- SIEM integration
- Penetration testing program
- Security documentation portal
- Compliance automation

### Year 2
- SOC 2 Type II certification
- HIPAA compliance option
- Privacy shield frameworks
- Advanced DLP (Data Loss Prevention)
- Zero-trust network architecture

---

**Document Version:** 1.0  
**Last Updated:** [Current Date]  
**Author:** SaaS Architecture Team  
**Review Cycle:** Quarterly
