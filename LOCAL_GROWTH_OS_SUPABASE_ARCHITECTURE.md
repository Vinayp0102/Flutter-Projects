# Local Growth OS - Supabase Architecture

## Overview

This document details the complete Supabase-based architecture for Local Growth OS, leveraging Supabase's Backend-as-a-Service capabilities for rapid development while maintaining enterprise-grade scalability and security.

---

## 1. Architecture Overview

### 1.1 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CLIENT LAYER                                   │
├─────────────────┬─────────────────┬─────────────────────────────────────┤
│   Web App       │   Mobile Apps   │   Third-Party Integrations          │
│   (React/Next)  │   (React Nat)   │   (Zapier, API Consumers)           │
└────────┬────────┴────────┬────────┴──────────────┬──────────────────────┘
         │                 │                       │
         │    HTTPS/WSS    │                       │
         ▼                 ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        SUPABASE PLATFORM                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   Auth      │  │  Database   │  │   Storage   │  │   Realtime  │    │
│  │   Service   │  │ (PostgreSQL)│  │   (S3)      │  │   Engine    │    │
│  │             │  │             │  │             │  │             │    │
│  │ • Users     │  │ • Tables    │  │ • Avatars   │  │ • Presence  │    │
│  │ • Sessions  │  │ • RLS       │  │ • Files     │  │ • Changes   │    │
│  │ • MFA       │  │ • Functions │  │ • Backups   │  │ • Subscriptions│ │
│  │ • OAuth     │  │ • Triggers  │  │             │  │             │    │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    Edge Functions (Deno)                         │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │    │
│  │  │Webhooks  │ │Workflows │ │Integrat. │ │Custom    │           │    │
│  │  │Handler   │ │Engine    │ │Sync      │ │Logic     │           │    │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
         │                 │                       │
         │                 │                       │
         ▼                 ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      EXTERNAL SERVICES                                   │
├─────────────┬─────────────┬─────────────┬─────────────┬────────────────┤
│   Twilio    │  SendGrid   │   Stripe    │  Google     │   Facebook     │
│   (SMS)     │  (Email)    │ (Payments)  │  (GMB API)  │   (Graph API)  │
└─────────────┴─────────────┴─────────────┴─────────────┴────────────────┘
```

---

## 2. Supabase Services Configuration

### 2.1 Authentication Service

**Configuration:**
```typescript
// supabase/auth/config.ts
export const authConfig = {
  // Password policy
  passwordMinLength: 8,
  passwordRequireSpecialChar: true,
  passwordRequireNumber: true,
  
  // Session settings
  sessionExpiry: '30d',
  refreshTokenExpiry: '90d',
  
  // Rate limiting
  signUpRateLimit: '5/hour',
  signInRateLimit: '10/minute',
  
  // Email settings
  emailConfirmRequired: true,
  emailChangeRequired: false,
  
  // OAuth providers
  providers: {
    google: { enabled: true, clientId: env.GOOGLE_CLIENT_ID },
    microsoft: { enabled: false }, // Phase 2
    facebook: { enabled: false }, // Phase 2
  },
  
  // MFA settings
  mfa: {
    enabled: true,
    requiredForRoles: ['owner', 'admin'],
    totpEnabled: true,
    phoneEnabled: true,
  },
};
```

**Custom Claims in JWT:**
```typescript
// Extend Supabase JWT with custom claims
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "tenant_id": "tenant-uuid",
  "role": "admin",
  "permissions": ["leads:read", "leads:write"],
  "locations": ["location-uuid-1"],
  "mfa_verified": true
}
```

**Auth Hooks (Database Functions):**
```sql
-- Trigger to create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, tenant_id, email, role, status)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'tenant_id',
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'agent'),
    'invited'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### 2.2 Database Service

**Connection Pooling:**
```typescript
// Use Supabase connection pooler (PgBouncer)
const config = {
  host: 'db.project.supabase.co',
  port: 6543, // Transaction mode
  database: 'postgres',
  ssl: true,
  max: 20, // Max connections per instance
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
};
```

**RLS Policies Implementation:**

```sql
-- Enable RLS on all tables
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;
-- ... repeat for all tenant-scoped tables

-- Tenant isolation policy (apply to all tenant tables)
CREATE POLICY tenant_isolation_policy ON contacts
  FOR ALL
  USING (
    tenant_id = current_setting('app.current_tenant', true)::uuid
  );

-- Role-based access
CREATE POLICY role_based_select ON contacts
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = contacts.tenant_id
      AND profiles.status = 'active'
      AND profiles.role IN ('owner', 'admin', 'manager', 'agent')
    )
  );

CREATE POLICY role_based_insert ON contacts
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = contacts.tenant_id
      AND profiles.status = 'active'
      AND profiles.role IN ('owner', 'admin', 'manager', 'agent')
    )
  );

-- Assignment-based access (agents see only their leads)
CREATE POLICY assignment_based_access ON contacts
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

**Database Functions for Business Logic:**

```sql
-- Function to create contact with activity logging
CREATE OR REPLACE FUNCTION create_contact_with_activity(
  p_tenant_id uuid,
  p_first_name varchar,
  p_last_name varchar,
  p_email varchar,
  p_phone varchar,
  p_source varchar,
  p_assigned_to uuid
) RETURNS uuid AS $$
DECLARE
  v_contact_id uuid;
BEGIN
  -- Insert contact
  INSERT INTO contacts (
    tenant_id, first_name, last_name, email, phone, 
    source, assigned_to, status
  ) VALUES (
    p_tenant_id, p_first_name, p_last_name, p_email, 
    p_phone, p_source, p_assigned_to, 'new'
  ) RETURNING id INTO v_contact_id;
  
  -- Log activity
  INSERT INTO contact_activities (
    tenant_id, contact_id, activity_type, 
    subject, body, performed_by
  ) VALUES (
    p_tenant_id, v_contact_id, 'contact_created',
    'Contact created', 
    format('New %s lead from %s', p_source, p_first_name),
    auth.uid()
  );
  
  -- Trigger workflows
  PERFORM trigger_workflows_for_contact(v_contact_id, 'contact_created');
  
  RETURN v_contact_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 2.3 Realtime Service

**Realtime Subscriptions:**

```typescript
// Client-side realtime subscriptions
const channel = supabase
  .channel('dashboard-updates')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'contacts',
      filter: `tenant_id=eq.${tenantId}`
    },
    (payload) => {
      // Update UI with new/changed contacts
      updateContactsCache(payload);
    }
  )
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'conversations',
      filter: `tenant_id=eq.${tenantId}`
    },
    (payload) => {
      // Show notification for new conversation
      showNotification('New message received');
    }
  )
  .on(
    'presence',
    { event: 'sync' },
    () => {
      // Update online team members list
      updatePresenceList(channel.presenceState());
    }
  )
  .subscribe();

// Presence tracking for team members
channel.track({
  online_at: new Date().toISOString(),
  user_id: userId,
  user_name: userName,
  status: 'active'
});
```

**Realtime Features:**
- Live lead updates across team devices
- Instant messaging notifications
- Collaborative pipeline board (see who's viewing)
- Team presence indicators
- Workflow execution status updates

### 2.4 Storage Service

**Bucket Configuration:**

```typescript
// Storage buckets setup
const buckets = [
  {
    id: 'tenant-assets',
    name: 'Tenant Assets',
    public: false,
    fileSizeLimit: 10 * 1024 * 1024, // 10MB
    allowedMimeTypes: ['image/*', 'application/pdf'],
  },
  {
    id: 'form-uploads',
    name: 'Form Uploads',
    public: true,
    fileSizeLimit: 5 * 1024 * 1024, // 5MB
    allowedMimeTypes: ['image/*'],
  },
  {
    id: 'email-attachments',
    name: 'Email Attachments',
    public: false,
    fileSizeLimit: 25 * 1024 * 1024, // 25MB
    allowedMimeTypes: ['*'],
  },
];
```

**Storage RLS Policies:**

```sql
-- Bucket-level policies
CREATE POLICY "tenant_assets_isolation"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'tenant-assets'
  AND (storage.foldername(name))[1] = current_setting('app.current_tenant', true)
);

CREATE POLICY "tenant_assets_upload"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'tenant-assets'
  AND (storage.foldername(name))[1] = current_setting('app.current_tenant', true)
);

-- Avatar upload policy
CREATE POLICY "avatar_upload"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'tenant-assets'
  AND (storage.foldername(name))[2] = 'avatars'
  AND auth.uid()::text = (storage.foldername(name))[3]
);
```

**Signed URLs for Private Files:**

```typescript
// Generate signed URL for private file
const { data } = await supabase.storage
  .from('tenant-assets')
  .createSignedUrl(
    `${tenantId}/documents/contract.pdf`,
    60 // 60 seconds expiry
  );

// Use in UI
<img src={data.signedUrl} alt="Document" />
```

### 2.5 Edge Functions

**Edge Function Structure:**

```
supabase/
├── functions/
│   ├── webhooks/
│   │   ├── twilio-inbound/
│   │   │   └── index.ts
│   │   ├── stripe-webhook/
│   │   │   └── index.ts
│   │   └── facebook-leads/
│   │       └── index.ts
│   ├── workflows/
│   │   ├── execute-workflow/
│   │   │   └── index.ts
│   │   └── workflow-actions/
│   │       └── index.ts
│   ├── integrations/
│   │   ├── sync-google-reviews/
│   │   │   └── index.ts
│   │   └── send-sms/
│   │       └── index.ts
│   └── utils/
│       ├── supabase-client.ts
│       └── validators.ts
```

**Example Edge Function:**

```typescript
// supabase/functions/twilio-inbound/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req: Request) => {
  try {
    // Parse Twilio webhook
    const formData = await req.formData();
    const from = formData.get('From') as string;
    const body = formData.get('Body') as string;
    const to = formData.get('To') as string;
    
    // Find tenant by phone number
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    
    const { data: tenant } = await supabase
      .from('tenants')
      .select('id, settings')
      .eq('phone', to)
      .single();
    
    if (!tenant) {
      return new Response('Tenant not found', { status: 404 });
    }
    
    // Find or create contact
    const { data: contact } = await supabase
      .from('contacts')
      .select('id')
      .eq('tenant_id', tenant.id)
      .eq('phone', from)
      .single();
    
    // Create inbound SMS record
    await supabase.from('sms_messages').insert({
      tenant_id: tenant.id,
      contact_id: contact?.id,
      to_number: to,
      from_number: from,
      body: body,
      direction: 'inbound',
      status: 'received',
    });
    
    // Trigger conversation update
    await supabase.functions.invoke('update-conversation-last-message', {
      body: { tenantId: tenant.id, contactId: contact?.id },
    });
    
    return new Response('OK', { status: 200 });
  } catch (error) {
    console.error('Error processing webhook:', error);
    return new Response('Error', { status: 500 });
  }
});
```

**Deploy Edge Functions:**

```bash
# Deploy all functions
supabase functions deploy

# Deploy specific function
supabase functions deploy twilio-inbound

# Set environment variables
supabase secrets set TWILIO_AUTH_TOKEN=xxx
supabase secrets set SENDGRID_API_KEY=xxx
```

---

## 3. Multi-Tenancy Implementation

### 3.1 Tenant Isolation Strategy

**Approach:** Row-Level Security (RLS) with tenant_id column

**Benefits:**
- Single database, lower cost
- Easier maintenance and updates
- Cross-tenant analytics possible (anonymized)
- Simpler backup strategy

**Implementation:**

```sql
-- Set tenant context at session level
-- Called after authentication on every request
SELECT set_config('app.current_tenant', $1, true);

-- RLS uses this context for all policy checks
CREATE POLICY isolation ON contacts
  USING (tenant_id = current_setting('app.current_tenant')::uuid);
```

**Middleware to Set Context:**

```typescript
// middleware/set-tenant-context.ts
import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs';

export async function setTenantContext(req: Request, res: Response) {
  const supabase = createMiddlewareClient({ req, res });
  const { data: { session } } = await supabase.auth.getSession();
  
  if (!session) {
    throw new Error('Unauthorized');
  }
  
  // Get tenant from user's profile
  const { data: profile } = await supabase
    .from('profiles')
    .select('tenant_id')
    .eq('id', session.user.id)
    .single();
  
  // Set context for subsequent queries
  await supabase.rpc('set_tenant_context', { 
    tenant_id: profile.tenant_id 
  });
  
  return { tenantId: profile.tenant_id, supabase };
}
```

### 3.2 Tenant Onboarding Flow

```typescript
async function onboardNewTenant(tenantData: TenantInput) {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  
  // Start transaction
  const { data: tenant, error } = await supabase
    .from('tenants')
    .insert({
      name: tenantData.name,
      slug: generateSlug(tenantData.name),
      industry: tenantData.industry,
      status: 'trial',
      subscription_tier: 'starter',
    })
    .select()
    .single();
  
  if (error) throw error;
  
  // Create default location
  await supabase.from('locations').insert({
    tenant_id: tenant.id,
    name: tenantData.name,
    is_primary: true,
  });
  
  // Apply industry template
  await applyIndustryTemplate(tenant.id, tenantData.industry);
  
  // Create owner profile
  await supabase.from('profiles').insert({
    id: tenantData.ownerUserId,
    tenant_id: tenant.id,
    email: tenantData.ownerEmail,
    role: 'owner',
    status: 'active',
  });
  
  return tenant;
}
```

---

## 4. Integration Architecture

### 4.1 Outbound Integrations (Platform → External)

**Pattern:** Edge Functions + Queue System

```typescript
// Workflow action: Send SMS via Twilio
export async function sendSmsAction(params: ActionParams) {
  const { contactId, templateId, variables } = params;
  
  // Get contact and template
  const [contact, template] = await Promise.all([
    supabase.from('contacts').select('phone').eq('id', contactId).single(),
    supabase.from('message_templates').select('content').eq('id', templateId).single(),
  ]);
  
  // Render template
  const message = renderTemplate(template.content, variables);
  
  // Call Twilio via Edge Function
  const response = await fetch(`${SUPABASE_URL}/functions/v1/send-sms`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${SERVICE_KEY}` },
    body: JSON.stringify({
      to: contact.phone,
      body: message,
    }),
  });
  
  // Record result
  await supabase.from('sms_messages').insert({
    tenant_id: params.tenantId,
    contact_id: contactId,
    to_number: contact.phone,
    body: message,
    direction: 'outbound',
    status: response.ok ? 'sent' : 'failed',
  });
}
```

### 4.2 Inbound Integrations (External → Platform)

**Pattern:** Webhooks → Edge Functions → Database

**Twilio Webhook Handler:**
```typescript
// POST /functions/v1/webhooks/twilio-inbound
export async function handleTwilioWebhook(request: Request) {
  const body = await request.formData();
  const from = body.get('From');
  const to = body.get('To');
  const messageBody = body.get('Body');
  
  // Verify Twilio signature
  const isValid = verifyTwilioSignature(request, TWILIO_AUTH_TOKEN);
  if (!isValid) return new Response('Invalid signature', { status: 401 });
  
  // Process message (see example above)
  await processInboundSms(from, to, messageBody);
  
  return new Response('OK');
}
```

**Facebook Lead Ads Webhook:**
```typescript
// POST /functions/v1/webhooks/facebook-leads
export async function handleFacebookLeads(request: Request) {
  const payload = await request.json();
  
  // Verify Facebook signature
  const isValid = verifyFacebookSignature(request, FB_APP_SECRET);
  if (!isValid) return new Response('Invalid signature', { status: 401 });
  
  // Process lead
  for (const entry of payload.entry) {
    for (const change of entry.changes) {
      if (change.field === 'leadgen') {
        await processFacebookLead(change.value);
      }
    }
  }
  
  return new Response('OK');
}
```

### 4.3 Scheduled Jobs (Cron)

**Using Supabase Cron + Edge Functions:**

```yaml
# supabase/cron.toml
[[jobs]]
name = "sync-google-reviews"
schedule = "0 * * * *" # Every hour
function = "sync-google-reviews"

[[jobs]]
name = "daily-metrics-aggregation"
schedule = "0 0 * * *" # Daily at midnight
function = "aggregate-daily-metrics"

[[jobs]]
name = "workflow-trigger-check"
schedule = "* * * * *" # Every minute
function = "check-workflow-triggers"

[[jobs]]
name = "stale-lead-alerts"
schedule = "0 9 * * *" # Daily at 9 AM
function = "send-stale-lead-alerts"
```

---

## 5. Scalability Considerations

### 5.1 Database Scaling

**Read Replicas (Phase 2+):**
```typescript
// Configure read replica for analytics queries
const readSupabase = createClient(
  READ_REPLICA_URL,
  ANON_KEY
);

// Write operations go to primary
const writeSupabase = createClient(
  PRIMARY_URL,
  ANON_KEY
);

// Use read replica for dashboard analytics
const metrics = await readSupabase
  .from('daily_metrics')
  .select('*')
  .eq('tenant_id', tenantId);
```

**Table Partitioning (for large tables):**
```sql
-- Partition sms_messages by date
CREATE TABLE sms_messages_partitioned (
  LIKE sms_messages INCLUDING ALL
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE sms_messages_2024_01 
  PARTITION OF sms_messages_partitioned
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

### 5.2 Caching Strategy

**Redis Cache (via Supabase):**
```typescript
// Cache frequently accessed data
async function getCachedTenantSettings(tenantId: string) {
  const cacheKey = `tenant:${tenantId}:settings`;
  
  // Try cache first
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);
  
  // Fetch from database
  const { data } = await supabase
    .from('tenants')
    .select('settings')
    .eq('id', tenantId)
    .single();
  
  // Cache for 5 minutes
  await redis.setex(cacheKey, 300, JSON.stringify(data.settings));
  
  return data.settings;
}
```

### 5.3 Rate Limiting

**Per-Tenant Rate Limits:**
```typescript
// Redis-based rate limiting
async function checkRateLimit(tenantId: string, action: string) {
  const key = `ratelimit:${tenantId}:${action}`;
  const limit = getLimitForPlan(tenantId, action);
  const window = 60; // 1 minute
  
  const current = await redis.incr(key);
  if (current === 1) {
    await redis.expire(key, window);
  }
  
  if (current > limit) {
    throw new RateLimitError(`Exceeded ${limit} ${action}/minute`);
  }
  
  return { remaining: limit - current, resetIn: window };
}
```

---

## 6. Monitoring & Observability

### 6.1 Supabase Dashboard Metrics

**Tracked Metrics:**
- Database size and growth
- API requests per second
- Function invocation count
- Storage usage
- Active connections
- Query performance (slow queries)

### 6.2 Custom Monitoring

```typescript
// Log important events to analytics
await supabase.from('audit_logs').insert({
  tenant_id: tenantId,
  profile_id: userId,
  action: 'contact_created',
  resource_type: 'contact',
  resource_id: contactId,
  ip_address: req.ip,
  user_agent: req.headers.get('user-agent'),
});

// Track performance
const start = Date.now();
// ... operation
const duration = Date.now() - start;
await logMetric('operation_duration', { operation, duration, tenantId });
```

---

## 7. Cost Optimization

### 7.1 Supabase Plan Selection

| Feature | Pro ($25/mo) | Team ($25/user/mo) | Enterprise |
|---------|--------------|---------------------|------------|
| Database | 8GB | 8GB+ | Custom |
| Auth MAU | 50K | 50K+ | Custom |
| Functions | 500K invocations | 500K+ | Custom |
| Support | Community | Email | Dedicated |

**Recommendation:** Start with Pro, scale to Team at 100+ tenants

### 7.2 Query Optimization

```sql
-- Use indexes effectively
CREATE INDEX idx_contacts_tenant_status 
ON contacts(tenant_id, status) 
WHERE deleted_at IS NULL;

-- Avoid SELECT *
SELECT id, first_name, last_name, status 
FROM contacts 
WHERE tenant_id = $1;

-- Use LIMIT for large result sets
SELECT * FROM contact_activities
WHERE tenant_id = $1
ORDER BY created_at DESC
LIMIT 50 OFFSET 0;
```

---

**Document Version:** 1.0  
**Last Updated:** [Current Date]  
**Author:** SaaS Architecture Team
