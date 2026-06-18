# Local Growth OS - Database Design

## Overview

This document details the complete database schema for Local Growth OS, designed for Supabase (PostgreSQL) with multi-tenancy, scalability, and performance in mind.

---

## Design Principles

1. **Multi-Tenancy:** Row-Level Security (RLS) ensures data isolation per tenant
2. **Soft Deletes:** All critical tables use `deleted_at` instead of hard deletes
3. **Audit Trail:** Created/updated timestamps and user tracking on all tables
4. **Indexing Strategy:** Strategic indexes for common query patterns
5. **Partitioning:** Large tables prepared for future partitioning
6. **JSONB Flexibility:** Hybrid relational + document approach for custom fields

---

## Core Schema

### 1. Tenants & Organizations

```sql
-- Main tenant table - each row is a business customer
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL, -- For subdomain routing
    industry VARCHAR(50) NOT NULL, -- salon, clinic, gym, coaching, real_estate, packers_movers
    status VARCHAR(20) DEFAULT 'active', -- active, suspended, cancelled, trial
    subscription_tier VARCHAR(50) DEFAULT 'starter', -- starter, professional, business, enterprise
    subscription_status VARCHAR(50) DEFAULT 'trial', -- trial, active, past_due, cancelled
    stripe_customer_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255),
    settings JSONB DEFAULT '{}', -- Tenant-wide settings
    branding JSONB DEFAULT '{}', -- Logo, colors, etc.
    timezone VARCHAR(50) DEFAULT 'UTC',
    currency VARCHAR(3) DEFAULT 'USD',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Multiple locations per tenant
CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(50) DEFAULT 'US',
    phone VARCHAR(20),
    email VARCHAR(255),
    google_place_id VARCHAR(255), -- For Google My Business integration
    facebook_page_id VARCHAR(255), -- For Facebook integration
    settings JSONB DEFAULT '{}',
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_locations_tenant_id ON locations(tenant_id);
CREATE INDEX idx_locations_deleted_at ON locations(deleted_at) WHERE deleted_at IS NULL;
```

### 2. Users & Authentication

```sql
-- Extends Supabase auth.users with application-specific data
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    avatar_url TEXT,
    role VARCHAR(50) NOT NULL, -- admin, manager, agent, front_desk
    status VARCHAR(20) DEFAULT 'active', -- active, inactive, invited, suspended
    invitation_token VARCHAR(255),
    invitation_expires_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    preferences JSONB DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_profiles_tenant_id ON profiles(tenant_id);
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_status ON profiles(status);

-- Custom roles and permissions
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    permissions JSONB NOT NULL DEFAULT '[]', -- Array of permission strings
    is_system_role BOOLEAN DEFAULT FALSE, -- Cannot be deleted
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_roles_tenant_id ON roles(tenant_id);

-- Team member to location assignment
CREATE TABLE team_location_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
    can_access_all_data BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(profile_id, location_id)
);

CREATE INDEX idx_team_assignments_profile ON team_location_assignments(profile_id);
CREATE INDEX idx_team_assignments_location ON team_location_assignments(location_id);
```

### 3. Leads & Contacts

```sql
-- Main leads/contacts table
CREATE TABLE contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    source VARCHAR(50) NOT NULL, -- website, facebook, google, walk_in, phone, referral, import
    type VARCHAR(20) DEFAULT 'lead', -- lead, customer, both
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(20),
    alternate_phone VARCHAR(20),
    company VARCHAR(255),
    job_title VARCHAR(100),
    status VARCHAR(50) DEFAULT 'new', -- new, contacted, qualified, proposal, negotiated, won, lost, unqualified
    priority VARCHAR(20) DEFAULT 'medium', -- low, medium, high, urgent
    lead_score INTEGER DEFAULT 0,
    assigned_to UUID REFERENCES profiles(id),
    pipeline_id UUID REFERENCES pipelines(id),
    stage_id UUID REFERENCES pipeline_stages(id),
    location_id UUID REFERENCES locations(id),
    tags TEXT[], -- Array of tag strings
    custom_fields JSONB DEFAULT '{}', -- Dynamic custom fields
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    utm_content VARCHAR(100),
    utm_term VARCHAR(100),
    referrer_url TEXT,
    landing_page_url TEXT,
    last_contacted_at TIMESTAMPTZ,
    last_activity_at TIMESTAMPTZ,
    converted_at TIMESTAMPTZ, -- When became customer
    lost_reason TEXT,
    won_value DECIMAL(12,2),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_contacts_tenant_id ON contacts(tenant_id);
CREATE INDEX idx_contacts_status ON contacts(tenant_id, status);
CREATE INDEX idx_contacts_assigned_to ON contacts(tenant_id, assigned_to);
CREATE INDEX idx_contacts_stage ON contacts(tenant_id, stage_id);
CREATE INDEX idx_contacts_created_at ON contacts(tenant_id, created_at DESC);
CREATE INDEX idx_contacts_last_activity ON contacts(tenant_id, last_activity_at DESC);
CREATE INDEX idx_contacts_phone ON contacts(tenant_id, phone);
CREATE INDEX idx_contacts_email ON contacts(tenant_id, email);
CREATE INDEX idx_contacts_type ON contacts(tenant_id, type);
CREATE INDEX idx_contacts_tags ON contacts USING GIN(tags);

-- Prevent duplicate contacts within tenant
CREATE UNIQUE INDEX idx_contacts_unique_phone 
ON contacts(tenant_id, phone) 
WHERE phone IS NOT NULL AND deleted_at IS NULL;

CREATE UNIQUE INDEX idx_contacts_unique_email 
ON contacts(tenant_id, email) 
WHERE email IS NOT NULL AND deleted_at IS NULL;

-- Pipeline definitions
CREATE TABLE pipelines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    type VARCHAR(50) DEFAULT 'sales', -- sales, recruitment, etc.
    is_default BOOLEAN DEFAULT FALSE,
    color VARCHAR(20),
    position INTEGER DEFAULT 0,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_pipelines_tenant_id ON pipelines(tenant_id);

-- Pipeline stages
CREATE TABLE pipeline_stages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pipeline_id UUID NOT NULL REFERENCES pipelines(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    position INTEGER NOT NULL,
    probability INTEGER DEFAULT 0, -- Win probability percentage
    color VARCHAR(20),
    auto_actions JSONB DEFAULT '[]', -- Actions triggered when entering stage
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_pipeline_stages_pipeline ON pipeline_stages(pipeline_id);
CREATE INDEX idx_pipeline_stages_position ON pipeline_stages(pipeline_id, position);

-- Contact activity timeline
CREATE TABLE contact_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    performed_by UUID REFERENCES profiles(id),
    activity_type VARCHAR(50) NOT NULL, -- call, email, sms, note, meeting, task, status_change, workflow_action
    subject VARCHAR(255),
    body TEXT,
    direction VARCHAR(20), -- inbound, outbound, internal (for communications)
    channel VARCHAR(50), -- phone, email, sms, whatsapp, web, in_person
    status VARCHAR(50), -- completed, scheduled, cancelled, failed
    scheduled_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_activities_contact ON contact_activities(contact_id);
CREATE INDEX idx_activities_tenant_date ON contact_activities(tenant_id, created_at DESC);
CREATE INDEX idx_activities_type ON contact_activities(tenant_id, activity_type);
CREATE INDEX idx_activities_performed_by ON contact_activities(tenant_id, performed_by);

-- Notes on contacts
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES profiles(id),
    content TEXT NOT NULL,
    is_pinned BOOLEAN DEFAULT FALSE,
    visibility VARCHAR(20) DEFAULT 'team', -- team, private, admin_only
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_notes_contact ON notes(contact_id);
CREATE INDEX idx_notes_tenant ON notes(tenant_id, created_at DESC);
CREATE INDEX idx_notes_created_by ON notes(tenant_id, created_by);
```

### 4. Automation & Workflows

```sql
-- Workflow definitions
CREATE TABLE workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL, -- lead_nurture, review_request, appointment_reminder, re_engagement, custom
    status VARCHAR(20) DEFAULT 'draft', -- draft, active, paused, archived
    trigger_type VARCHAR(50) NOT NULL, -- time_based, action_based, date_based, webhook
    trigger_config JSONB NOT NULL, -- Trigger configuration
    definition JSONB NOT NULL, -- Workflow node graph
    statistics JSONB DEFAULT '{}', -- Execution stats
    version INTEGER DEFAULT 1,
    is_template BOOLEAN DEFAULT FALSE,
    template_category VARCHAR(100),
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_workflows_tenant_id ON workflows(tenant_id);
CREATE INDEX idx_workflows_status ON workflows(tenant_id, status);
CREATE INDEX idx_workflows_type ON workflows(tenant_id, type);

-- Workflow executions (instances)
CREATE TABLE workflow_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
    contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'running', -- running, completed, failed, cancelled
    current_node_id VARCHAR(100),
    context JSONB DEFAULT '{}', -- Runtime context
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_executions_workflow ON workflow_executions(workflow_id);
CREATE INDEX idx_executions_contact ON workflow_executions(contact_id);
CREATE INDEX idx_executions_status ON workflow_executions(tenant_id, status);
CREATE INDEX idx_executions_started_at ON workflow_executions(tenant_id, started_at DESC);

-- Workflow execution logs (per node)
CREATE TABLE workflow_execution_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    execution_id UUID NOT NULL REFERENCES workflow_executions(id) ON DELETE CASCADE,
    node_id VARCHAR(100) NOT NULL,
    node_type VARCHAR(50) NOT NULL, -- action, condition, wait, trigger
    action_type VARCHAR(100), -- send_sms, send_email, update_status, etc.
    status VARCHAR(20) DEFAULT 'pending', -- pending, running, completed, failed, skipped
    input_data JSONB,
    output_data JSONB,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    executed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_execution_logs_execution ON workflow_execution_logs(execution_id);
CREATE INDEX idx_execution_logs_node ON workflow_execution_logs(execution_id, node_id);

-- Message templates
CREATE TABLE message_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL, -- sms, email, whatsapp
    category VARCHAR(100), -- follow_up, review_request, appointment, broadcast
    subject VARCHAR(255), -- For email
    content TEXT NOT NULL,
    variables TEXT[], -- Available template variables
    language VARCHAR(10) DEFAULT 'en',
    is_system_template BOOLEAN DEFAULT FALSE,
    usage_count INTEGER DEFAULT 0,
    conversion_rate DECIMAL(5,2), -- If A/B tested
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_templates_tenant ON message_templates(tenant_id);
CREATE INDEX idx_templates_type ON message_templates(tenant_id, type);
CREATE INDEX idx_templates_category ON message_templates(tenant_id, category);
```

### 5. Communications

```sql
-- SMS messages
CREATE TABLE sms_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
    conversation_id UUID REFERENCES conversations(id),
    from_number VARCHAR(20),
    to_number VARCHAR(20) NOT NULL,
    body TEXT NOT NULL,
    direction VARCHAR(20) NOT NULL, -- inbound, outbound
    status VARCHAR(20) DEFAULT 'queued', -- queued, sending, sent, delivered, failed, undelivered
    provider VARCHAR(50) DEFAULT 'twilio',
    provider_message_id VARCHAR(255),
    segments INTEGER DEFAULT 1,
    cost_cents INTEGER DEFAULT 0,
    error_code VARCHAR(50),
    error_message TEXT,
    metadata JSONB DEFAULT '{}',
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sms_contact ON sms_messages(contact_id);
CREATE INDEX idx_sms_conversation ON sms_messages(conversation_id);
CREATE INDEX idx_sms_tenant_date ON sms_messages(tenant_id, created_at DESC);
CREATE INDEX idx_sms_status ON sms_messages(tenant_id, status);
CREATE INDEX idx_sms_direction ON sms_messages(tenant_id, direction);

-- Email messages
CREATE TABLE email_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
    conversation_id UUID REFERENCES conversations(id),
    from_email VARCHAR(255) NOT NULL,
    to_email VARCHAR(255) NOT NULL,
    cc_emails TEXT[],
    bcc_emails TEXT[],
    subject VARCHAR(500),
    body_html TEXT,
    body_text TEXT,
    direction VARCHAR(20) NOT NULL, -- inbound, outbound
    status VARCHAR(20) DEFAULT 'queued', -- queued, sending, sent, delivered, opened, clicked, bounced, failed
    provider VARCHAR(50) DEFAULT 'sendgrid',
    provider_message_id VARCHAR(255),
    open_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    bounce_reason TEXT,
    error_message TEXT,
    headers JSONB DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_email_contact ON email_messages(contact_id);
CREATE INDEX idx_email_conversation ON email_messages(conversation_id);
CREATE INDEX idx_email_tenant_date ON email_messages(tenant_id, created_at DESC);
CREATE INDEX idx_email_status ON email_messages(tenant_id, status);

-- Conversations (unified inbox threads)
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    channel VARCHAR(50) NOT NULL, -- sms, email, whatsapp, facebook, mixed
    subject VARCHAR(255),
    status VARCHAR(20) DEFAULT 'open', -- open, closed, waiting, spam
    priority VARCHAR(20) DEFAULT 'normal', -- low, normal, high, urgent
    assigned_to UUID REFERENCES profiles(id),
    last_message_at TIMESTAMPTZ,
    last_message_from VARCHAR(20), -- customer, team
    unread_count INTEGER DEFAULT 0,
    tags TEXT[],
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_conversations_contact ON conversations(contact_id);
CREATE INDEX idx_conversations_tenant ON conversations(tenant_id, last_message_at DESC);
CREATE INDEX idx_conversations_assigned ON conversations(tenant_id, assigned_to);
CREATE INDEX idx_conversations_status ON conversations(tenant_id, status);
CREATE INDEX idx_conversations_channel ON conversations(tenant_id, channel);

-- Conversation participants (team members)
CREATE TABLE conversation_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'participant', -- participant, assignee, observer
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    UNIQUE(conversation_id, profile_id)
);

CREATE INDEX idx_conv_participants_conversation ON conversation_participants(conversation_id);
CREATE INDEX idx_conv_participants_profile ON conversation_participants(profile_id);
```

### 6. Reviews

```sql
-- Review platforms connected
CREATE TABLE review_platforms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    platform VARCHAR(50) NOT NULL, -- google, facebook, yelp
    location_id UUID REFERENCES locations(id),
    platform_account_id VARCHAR(255), -- Platform-specific account ID
    access_token TEXT, -- Encrypted
    refresh_token TEXT, -- Encrypted
    token_expires_at TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'active', -- active, error, disconnected
    last_synced_at TIMESTAMPTZ,
    sync_frequency_minutes INTEGER DEFAULT 60,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_review_platforms_tenant ON review_platforms(tenant_id);
CREATE UNIQUE INDEX idx_review_platforms_unique ON review_platforms(tenant_id, platform, location_id);

-- Reviews collected
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    platform VARCHAR(50) NOT NULL, -- google, facebook, yelp
    platform_review_id VARCHAR(255) NOT NULL, -- Platform's review ID
    location_id UUID REFERENCES locations(id),
    contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
    reviewer_name VARCHAR(255),
    reviewer_avatar_url TEXT,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(500),
    content TEXT,
    language VARCHAR(10),
    published_at TIMESTAMPTZ,
    response_content TEXT,
    responded_by UUID REFERENCES profiles(id),
    responded_at TIMESTAMPTZ,
    is_flagged BOOLEAN DEFAULT FALSE,
    flag_reason TEXT,
    sentiment VARCHAR(20), -- positive, neutral, negative (AI-analyzed)
    metadata JSONB DEFAULT '{}',
    fetched_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(platform, platform_review_id)
);

CREATE INDEX idx_reviews_tenant ON reviews(tenant_id);
CREATE INDEX idx_reviews_platform ON reviews(tenant_id, platform);
CREATE INDEX idx_reviews_rating ON reviews(tenant_id, rating);
CREATE INDEX idx_reviews_published_at ON reviews(tenant_id, published_at DESC);
CREATE INDEX idx_reviews_contact ON reviews(contact_id);

-- Review requests sent
CREATE TABLE review_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    platform VARCHAR(50), -- Specific platform or null for multi-platform
    channel VARCHAR(20) NOT NULL, -- sms, email
    message_template_id UUID REFERENCES message_templates(id),
    status VARCHAR(20) DEFAULT 'pending', -- pending, sent, clicked, reviewed, expired
    review_link_url TEXT,
    clicked_at TIMESTAMPTZ,
    review_id UUID REFERENCES reviews(id),
    reviewed_at TIMESTAMPTZ,
    reminder_count INTEGER DEFAULT 0,
    last_reminder_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    sent_at TIMESTAMPTZ
);

CREATE INDEX idx_review_requests_contact ON review_requests(contact_id);
CREATE INDEX idx_review_requests_status ON review_requests(tenant_id, status);
CREATE INDEX idx_review_requests_created_at ON review_requests(tenant_id, created_at DESC);
```

### 7. Appointments

```sql
-- Appointments/Scheduled events
CREATE TABLE appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    location_id UUID REFERENCES locations(id),
    service_provider_id UUID REFERENCES profiles(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    service_type VARCHAR(100),
    status VARCHAR(20) DEFAULT 'scheduled', -- scheduled, confirmed, completed, cancelled, no_show
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    timezone VARCHAR(50) DEFAULT 'UTC',
    booking_source VARCHAR(50), -- website, sms, phone, walk_in, calendar_import
    confirmation_status VARCHAR(20) DEFAULT 'pending', -- pending, confirmed, declined
    confirmed_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    cancelled_by VARCHAR(20), -- customer, business
    no_show_marked_at TIMESTAMPTZ,
    no_show_reason TEXT,
    reschedule_count INTEGER DEFAULT 0,
    original_start_time TIMESTAMPTZ,
    reminders_sent JSONB DEFAULT '[]', -- Array of reminder timestamps
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_appointments_contact ON appointments(contact_id);
CREATE INDEX idx_appointments_tenant_date ON appointments(tenant_id, start_time);
CREATE INDEX idx_appointments_status ON appointments(tenant_id, status);
CREATE INDEX idx_appointments_provider ON appointments(tenant_id, service_provider_id);
CREATE INDEX idx_appointments_location ON appointments(tenant_id, location_id);

-- Calendar integrations
CREATE TABLE calendar_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES profiles(id),
    provider VARCHAR(50) NOT NULL, -- google, outlook, apple
    account_email VARCHAR(255) NOT NULL,
    access_token TEXT NOT NULL, -- Encrypted
    refresh_token TEXT, -- Encrypted
    token_expires_at TIMESTAMPTZ,
    calendar_ids TEXT[], -- Connected calendar IDs
    sync_enabled BOOLEAN DEFAULT TRUE,
    two_way_sync BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'active', -- active, error, disconnected
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_calendar_integrations_tenant ON calendar_integrations(tenant_id);
CREATE INDEX idx_calendar_integrations_profile ON calendar_integrations(profile_id);
```

### 8. Analytics & Reporting

```sql
-- Aggregated daily metrics for fast dashboard queries
CREATE TABLE daily_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    location_id UUID REFERENCES locations(id),
    date DATE NOT NULL,
    metric_type VARCHAR(50) NOT NULL, -- leads, conversions, messages, reviews, revenue, appointments
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(20,2) NOT NULL,
    dimensions JSONB DEFAULT '{}', -- Breakdown dimensions
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, date, metric_type, metric_name, dimensions)
);

CREATE INDEX idx_daily_metrics_tenant_date ON daily_metrics(tenant_id, date DESC);
CREATE INDEX idx_daily_metrics_type ON daily_metrics(tenant_id, metric_type);

-- Campaign tracking
CREATE TABLE campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL, -- broadcast, drip, nurture, seasonal
    channel VARCHAR(50), -- sms, email, multi_channel
    status VARCHAR(20) DEFAULT 'draft', -- draft, scheduled, active, completed, paused
    audience_filter JSONB, -- Target audience criteria
    message_template_id UUID REFERENCES message_templates(id),
    scheduled_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    total_recipients INTEGER DEFAULT 0,
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_opened INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    total_converted INTEGER DEFAULT 0,
    total_cost_cents INTEGER DEFAULT 0,
    revenue_attributed DECIMAL(12,2) DEFAULT 0,
    settings JSONB DEFAULT '{}',
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_campaigns_tenant ON campaigns(tenant_id);
CREATE INDEX idx_campaigns_status ON campaigns(tenant_id, status);
CREATE INDEX idx_campaigns_type ON campaigns(tenant_id, type);

-- Campaign recipients tracking
CREATE TABLE campaign_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending', -- pending, sent, delivered, opened, clicked, converted, bounced, failed
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    converted_at TIMESTAMPTZ,
    conversion_value DECIMAL(12,2),
    error_message TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(campaign_id, contact_id)
);

CREATE INDEX idx_campaign_recipients_campaign ON campaign_recipients(campaign_id);
CREATE INDEX idx_campaign_recipients_contact ON campaign_recipients(contact_id);
CREATE INDEX idx_campaign_recipients_status ON campaign_recipients(status);
```

### 9. Billing & Subscriptions

```sql
-- Subscription plans
CREATE TABLE subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    stripe_price_id VARCHAR(255),
    monthly_price_cents INTEGER NOT NULL,
    yearly_price_cents INTEGER,
    contact_limit INTEGER,
    user_limit INTEGER,
    features JSONB NOT NULL, -- Feature flags included
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Usage tracking for quota enforcement
CREATE TABLE usage_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    contacts_count INTEGER DEFAULT 0,
    users_count INTEGER DEFAULT 0,
    sms_sent INTEGER DEFAULT 0,
    emails_sent INTEGER DEFAULT 0,
    workflows_executed INTEGER DEFAULT 0,
    api_calls INTEGER DEFAULT 0,
    storage_bytes BIGINT DEFAULT 0,
    overage_charges_cents INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, period_start)
);

CREATE INDEX idx_usage_tracking_tenant ON usage_tracking(tenant_id);

-- Invoices
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    stripe_invoice_id VARCHAR(255),
    amount_cents INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(20) DEFAULT 'pending', -- pending, paid, failed, void, refunded
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    line_items JSONB DEFAULT '[]',
    hosted_invoice_url TEXT,
    invoice_pdf_url TEXT,
    paid_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    failure_reason TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_invoices_tenant ON invoices(tenant_id);
CREATE INDEX idx_invoices_status ON invoices(tenant_id, status);
CREATE INDEX idx_invoices_period ON invoices(tenant_id, period_start, period_end);
```

### 10. System & Audit

```sql
-- API keys for integrations
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL, -- Hashed, never store plain text
    key_prefix VARCHAR(20) NOT NULL, -- For identification (first 8 chars)
    permissions JSONB DEFAULT '{}',
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_api_keys_tenant ON api_keys(tenant_id);
CREATE UNIQUE INDEX idx_api_keys_hash ON api_keys(key_hash);

-- Audit log for compliance
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES profiles(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),
    resource_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    occurred_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_tenant ON audit_logs(tenant_id);
CREATE INDEX idx_audit_logs_profile ON audit_logs(tenant_id, profile_id);
CREATE INDEX idx_audit_logs_resource ON audit_logs(tenant_id, resource_type, resource_id);
CREATE INDEX idx_audit_logs_occurred_at ON audit_logs(tenant_id, occurred_at DESC);

-- Webhooks configuration
CREATE TABLE webhooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    events TEXT[] NOT NULL, -- Events to subscribe to
    secret VARCHAR(255) NOT NULL, -- For signature verification
    is_active BOOLEAN DEFAULT TRUE,
    last_triggered_at TIMESTAMPTZ,
    failure_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_webhooks_tenant ON webhooks(tenant_id);

-- Webhook delivery attempts
CREATE TABLE webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webhook_id UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    response_status INTEGER,
    response_body TEXT,
    attempt_count INTEGER DEFAULT 1,
    next_retry_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_webhook_deliveries_webhook ON webhook_deliveries(webhook_id);
CREATE INDEX idx_webhook_deliveries_status ON webhook_deliveries(delivered_at) WHERE delivered_at IS NULL;
```

---

## Row-Level Security (RLS) Policies

### Enable RLS on all tenant-scoped tables

```sql
-- Example RLS policy pattern (apply to all tenant-scoped tables)
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see data from their tenant
CREATE POLICY "tenant_isolation_policy" ON contacts
    FOR ALL
    USING (tenant_id IN (
        SELECT id FROM tenants WHERE id = contacts.tenant_id
    ));

-- Policy: Only active tenants can access data
CREATE POLICY "active_tenant_policy" ON contacts
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM tenants 
            WHERE id = contacts.tenant_id 
            AND status = 'active'
            AND deleted_at IS NULL
        )
    );

-- Policy: Team members can only access based on role
CREATE POLICY "role_based_access_policy" ON contacts
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid()
            AND profiles.tenant_id = contacts.tenant_id
            AND profiles.status = 'active'
        )
    );
```

---

## Database Functions & Triggers

### Automatic updated_at timestamp

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER update_contacts_updated_at
    BEFORE UPDATE ON contacts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### Soft delete handling

```sql
CREATE OR REPLACE FUNCTION soft_delete()
RETURNS TRIGGER AS $$
BEGIN
    NEW.deleted_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Example: Apply to contacts
CREATE TRIGGER contacts_soft_delete
    BEFORE DELETE ON contacts
    FOR EACH ROW
    EXECUTE FUNCTION soft_delete();
```

### Daily metrics aggregation

```sql
CREATE OR REPLACE FUNCTION aggregate_daily_metrics()
RETURNS VOID AS $$
BEGIN
    -- Aggregate leads count
    INSERT INTO daily_metrics (tenant_id, date, metric_type, metric_name, metric_value)
    SELECT 
        tenant_id,
        DATE(created_at) as date,
        'leads' as metric_type,
        'total_created' as metric_name,
        COUNT(*)::DECIMAL as metric_value
    FROM contacts
    WHERE created_at >= CURRENT_DATE - INTERVAL '1 day'
    AND created_at < CURRENT_DATE
    AND deleted_at IS NULL
    GROUP BY tenant_id, DATE(created_at)
    ON CONFLICT (tenant_id, date, metric_type, metric_name) 
    DO UPDATE SET metric_value = EXCLUDED.metric_value;
    
    -- Add more aggregations for other metrics...
END;
$$ LANGUAGE plpgsql;
```

---

## Index Optimization Strategy

### Composite Indexes for Common Queries

```sql
-- Dashboard queries: tenant + recent activity
CREATE INDEX idx_contacts_dashboard ON contacts(tenant_id, created_at DESC) 
WHERE deleted_at IS NULL;

-- Pipeline views: tenant + stage + assignment
CREATE INDEX idx_contacts_pipeline ON contacts(tenant_id, stage_id, assigned_to)
WHERE deleted_at IS NULL AND status NOT IN ('won', 'lost');

-- Inbox queries: tenant + last message + status
CREATE INDEX idx_conversations_inbox ON conversations(tenant_id, last_message_at DESC, status)
WHERE deleted_at IS NULL;

-- Workflow executions: tenant + status + started
CREATE INDEX idx_executions_active ON workflow_executions(tenant_id, status, started_at)
WHERE status = 'running';
```

### Partial Indexes for Filtered Queries

```sql
-- Only active contacts
CREATE INDEX idx_contacts_active ON contacts(tenant_id, id)
WHERE deleted_at IS NULL AND status NOT IN ('lost', 'unqualified');

-- Only unread conversations
CREATE INDEX idx_conversations_unread ON conversations(tenant_id, last_message_at DESC)
WHERE unread_count > 0 AND status = 'open';

-- Only failed messages
CREATE INDEX idx_sms_failed ON sms_messages(tenant_id, created_at DESC)
WHERE status = 'failed';
```

---

## Data Partitioning Strategy (Future Scale)

For tables expected to grow beyond 10M rows:

```sql
-- Example: Partition sms_messages by date
CREATE TABLE sms_messages_partitioned (
    LIKE sms_messages INCLUDING ALL
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE sms_messages_2024_01 PARTITION OF sms_messages_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE sms_messages_2024_02 PARTITION OF sms_messages_partitioned
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Similar approach for: email_messages, contact_activities, workflow_execution_logs
```

---

## Migration Strategy

### Version Control

- Use migration tool: Supabase Migrations or pgMigrate
- Each change in separate SQL file with version number
- Rollback scripts for every migration
- Test migrations on staging before production

### Zero-Downtime Deployments

1. Add new columns as nullable
2. Deploy code that writes to both old and new
3. Backfill existing data
4. Make column NOT NULL (if required)
5. Remove old column in subsequent migration

---

**Document Version:** 1.0  
**Last Updated:** [Current Date]  
**Author:** SaaS Architecture Team
