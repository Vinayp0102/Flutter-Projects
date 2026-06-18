-- ============================================================================
-- Local Growth OS - Supabase Database Schema
-- Production-Grade PostgreSQL Schema with RLS, Triggers, Functions
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. ENUMS
-- ============================================================================

CREATE TYPE business_type AS ENUM (
    'salon',
    'clinic',
    'gym',
    'coaching_institute',
    'real_estate',
    'packers_movers'
);

CREATE TYPE lead_status AS ENUM (
    'new',
    'contacted',
    'qualified',
    'proposal_sent',
    'negotiation',
    'won',
    'lost',
    'dead'
);

CREATE TYPE lead_source AS ENUM (
    'website',
    'google_my_business',
    'facebook',
    'instagram',
    'referral',
    'walk_in',
    'phone_call',
    'email',
    'advertisement',
    'other'
);

CREATE TYPE followup_status AS ENUM (
    'pending',
    'completed',
    'cancelled',
    'rescheduled'
);

CREATE TYPE followup_method AS ENUM (
    'call',
    'sms',
    'email',
    'whatsapp',
    'in_person'
);

CREATE TYPE user_role AS ENUM (
    'owner',
    'admin',
    'manager',
    'sales_agent',
    'front_desk',
    'staff'
);

CREATE TYPE communication_type AS ENUM (
    'sms',
    'email',
    'whatsapp',
    'call',
    'notification'
);

-- ============================================================================
-- 2. TABLES
-- ============================================================================

-- Users table (extends Supabase auth.users)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supabase_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    email VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20),
    avatar_url TEXT,
    role user_role NOT NULL DEFAULT 'staff',
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Businesses table (Multi-tenant core)
CREATE TABLE businesses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    business_type business_type NOT NULL,
    description TEXT,
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'US',
    phone_number VARCHAR(20),
    email VARCHAR(255),
    website_url TEXT,
    logo_url TEXT,
    timezone VARCHAR(50) DEFAULT 'America/New_York',
    currency VARCHAR(3) DEFAULT 'USD',
    settings JSONB DEFAULT '{}'::jsonb,
    subscription_plan VARCHAR(50) DEFAULT 'free',
    subscription_status VARCHAR(50) DEFAULT 'active',
    trial_ends_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Business Members (Many-to-Many between users and businesses)
CREATE TABLE business_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    role user_role NOT NULL,
    invited_at TIMESTAMPTZ DEFAULT NOW(),
    joined_at TIMESTAMPTZ,
    invited_by UUID REFERENCES users(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(business_id, user_id)
);

-- Leads table
CREATE TABLE leads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone_number VARCHAR(20),
    source lead_source DEFAULT 'other',
    status lead_status NOT NULL DEFAULT 'new',
    priority VARCHAR(20) DEFAULT 'medium',
    estimated_value DECIMAL(12, 2),
    currency VARCHAR(3) DEFAULT 'USD',
    notes_count INTEGER DEFAULT 0,
    followups_count INTEGER DEFAULT 0,
    last_contacted_at TIMESTAMPTZ,
    next_followup_at TIMESTAMPTZ,
    converted_at TIMESTAMPTZ,
    lost_reason TEXT,
    tags TEXT[],
    custom_fields JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Follow-ups table
CREATE TABLE followups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
    lead_id UUID REFERENCES leads(id) ON DELETE CASCADE NOT NULL,
    assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    method followup_method NOT NULL,
    status followup_status NOT NULL DEFAULT 'pending',
    scheduled_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    result TEXT,
    reminder_sent BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notes table
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
    lead_id UUID REFERENCES leads(id) ON DELETE CASCADE NOT NULL,
    author_id UUID REFERENCES users(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    is_internal BOOLEAN DEFAULT true,
    tags TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Communications table (for tracking all customer communications)
CREATE TABLE communications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
    lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    type communication_type NOT NULL,
    direction VARCHAR(20) NOT NULL, -- 'inbound' or 'outbound'
    subject VARCHAR(255),
    content TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'sent', -- sent, delivered, failed, read
    metadata JSONB DEFAULT '{}'::jsonb,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reviews table
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
    lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,
    reviewer_name VARCHAR(255),
    reviewer_email VARCHAR(255),
    reviewer_phone VARCHAR(20),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(255),
    content TEXT NOT NULL,
    source VARCHAR(50) DEFAULT 'internal', -- google, facebook, internal, etc.
    external_review_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending', -- pending, published, flagged, responded
    response_content TEXT,
    responded_by UUID REFERENCES users(id),
    responded_at TIMESTAMPTZ,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit Logs table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 3. INDEXES
-- ============================================================================

-- Users indexes
CREATE INDEX idx_users_supabase_user_id ON users(supabase_user_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Businesses indexes
CREATE INDEX idx_businesses_slug ON businesses(slug);
CREATE INDEX idx_businesses_type ON businesses(business_type);
CREATE INDEX idx_businesses_is_active ON businesses(is_active);
CREATE INDEX idx_businesses_subscription_status ON businesses(subscription_status);

-- Business Members indexes
CREATE INDEX idx_business_members_business_id ON business_members(business_id);
CREATE INDEX idx_business_members_user_id ON business_members(user_id);
CREATE INDEX idx_business_members_is_active ON business_members(is_active);

-- Leads indexes
CREATE INDEX idx_leads_business_id ON leads(business_id);
CREATE INDEX idx_leads_owner_id ON leads(owner_id);
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_source ON leads(source);
CREATE INDEX idx_leads_created_at ON leads(created_at DESC);
CREATE INDEX idx_leads_next_followup_at ON leads(next_followup_at) WHERE next_followup_at IS NOT NULL;
CREATE INDEX idx_leads_deleted_at ON leads(deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_leads_tags ON leads USING GIN(tags);
CREATE INDEX idx_leads_business_status ON leads(business_id, status);

-- Followups indexes
CREATE INDEX idx_followups_business_id ON followups(business_id);
CREATE INDEX idx_followups_lead_id ON followups(lead_id);
CREATE INDEX idx_followups_assigned_to ON followups(assigned_to);
CREATE INDEX idx_followups_status ON followups(status);
CREATE INDEX idx_followups_scheduled_at ON followups(scheduled_at);
CREATE INDEX idx_followups_business_status ON followups(business_id, status);
CREATE INDEX idx_followups_pending ON followups(scheduled_at, status) WHERE status = 'pending';

-- Notes indexes
CREATE INDEX idx_notes_business_id ON notes(business_id);
CREATE INDEX idx_notes_lead_id ON notes(lead_id);
CREATE INDEX idx_notes_author_id ON notes(author_id);
CREATE INDEX idx_notes_created_at ON notes(created_at DESC);
CREATE INDEX idx_notes_deleted_at ON notes(deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_notes_tags ON notes USING GIN(tags);

-- Communications indexes
CREATE INDEX idx_communications_business_id ON communications(business_id);
CREATE INDEX idx_communications_lead_id ON communications(lead_id);
CREATE INDEX idx_communications_user_id ON communications(user_id);
CREATE INDEX idx_communications_type ON communications(type);
CREATE INDEX idx_communications_created_at ON communications(created_at DESC);

-- Reviews indexes
CREATE INDEX idx_reviews_business_id ON reviews(business_id);
CREATE INDEX idx_reviews_lead_id ON reviews(lead_id);
CREATE INDEX idx_reviews_rating ON reviews(rating);
CREATE INDEX idx_reviews_status ON reviews(status);
CREATE INDEX idx_reviews_created_at ON reviews(created_at DESC);

-- Audit Logs indexes
CREATE INDEX idx_audit_logs_business_id ON audit_logs(business_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_table_name ON audit_logs(table_name);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);

-- ============================================================================
-- 4. FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to get current user ID from JWT
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('request.jwt.claims', true)::json->>'sub', '')::UUID;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current business ID from JWT claims
CREATE OR REPLACE FUNCTION get_current_business_id()
RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('request.jwt.claims', true)::json->'app_metadata'->>'business_id', '')::UUID;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is member of business
CREATE OR REPLACE FUNCTION is_business_member(check_business_id UUID, check_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    is_member BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM business_members
        WHERE business_id = check_business_id
        AND user_id = check_user_id
        AND is_active = true
    ) INTO is_member;
    RETURN is_member;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to soft delete a lead
CREATE OR REPLACE FUNCTION soft_delete_lead(lead_id_param UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE leads
    SET deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = lead_id_param
    AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to restore a soft deleted lead
CREATE OR REPLACE FUNCTION restore_lead(lead_id_param UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE leads
    SET deleted_at = NULL,
        updated_at = NOW()
    WHERE id = lead_id_param
    AND deleted_at IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create audit log entry
CREATE OR REPLACE FUNCTION create_audit_log(
    p_business_id UUID,
    p_user_id UUID,
    p_action VARCHAR,
    p_table_name VARCHAR,
    p_record_id UUID,
    p_old_values JSONB,
    p_new_values JSONB
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO audit_logs (
        business_id,
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        p_business_id,
        p_user_id,
        p_action,
        p_table_name,
        p_record_id,
        p_old_values,
        p_new_values,
        NULLIF(current_setting('request.headers', true)::json->>'x-forwarded-for', '')::INET,
        current_setting('request.headers', true)::json->>'user-agent'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment followups count on lead
CREATE OR REPLACE FUNCTION increment_followups_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE leads
        SET followups_count = followups_count + 1,
            updated_at = NOW()
        WHERE id = NEW.lead_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE leads
        SET followups_count = GREATEST(followups_count - 1, 0),
            updated_at = NOW()
        WHERE id = OLD.lead_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to increment notes count on lead
CREATE OR REPLACE FUNCTION increment_notes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE leads
        SET notes_count = notes_count + 1,
            updated_at = NOW()
        WHERE id = NEW.lead_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE leads
        SET notes_count = GREATEST(notes_count - 1, 0),
            updated_at = NOW()
        WHERE id = OLD.lead_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to update last contacted at on lead
CREATE OR REPLACE FUNCTION update_last_contacted_at()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status = 'completed' THEN
        UPDATE leads
        SET last_contacted_at = NEW.completed_at,
            updated_at = NOW()
        WHERE id = NEW.lead_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate unique business slug
CREATE OR REPLACE FUNCTION generate_unique_slug(business_name VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    base_slug VARCHAR;
    final_slug VARCHAR;
    counter INTEGER := 0;
BEGIN
    -- Create base slug from business name
    base_slug := LOWER(REGEXP_REPLACE(business_name, '[^a-zA-Z0-9]+', '-', 'g'));
    base_slug := REGEXP_REPLACE(base_slug, '^-+|-+$', '', 'g');
    
    final_slug := base_slug;
    
    -- Check if slug exists and append counter if needed
    WHILE EXISTS (SELECT 1 FROM businesses WHERE slug = final_slug) LOOP
        counter := counter + 1;
        final_slug := base_slug || '-' || counter::TEXT;
    END LOOP;
    
    RETURN final_slug;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. TRIGGERS
-- ============================================================================

-- Update updated_at triggers
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_businesses_updated_at
    BEFORE UPDATE ON businesses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_business_members_updated_at
    BEFORE UPDATE ON business_members
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_leads_updated_at
    BEFORE UPDATE ON leads
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_followups_updated_at
    BEFORE UPDATE ON followups
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notes_updated_at
    BEFORE UPDATE ON notes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Increment counters triggers
CREATE TRIGGER trigger_increment_followups_count
    AFTER INSERT OR DELETE ON followups
    FOR EACH ROW
    EXECUTE FUNCTION increment_followups_count();

CREATE TRIGGER trigger_increment_notes_count
    AFTER INSERT OR DELETE ON notes
    FOR EACH ROW
    EXECUTE FUNCTION increment_notes_count();

-- Update last contacted at trigger
CREATE TRIGGER trigger_update_last_contacted_at
    AFTER INSERT ON followups
    FOR EACH ROW
    EXECUTE FUNCTION update_last_contacted_at();

-- Auto-generate slug before insert
CREATE TRIGGER trigger_generate_business_slug
    BEFORE INSERT ON businesses
    FOR EACH ROW
    WHEN (NEW.slug IS NULL OR NEW.slug = '')
    EXECUTE FUNCTION generate_unique_slug(NEW.name);

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE communications ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- USERS RLS POLICIES
-- ============================================================================

-- Users can view their own profile
CREATE POLICY users_view_own_profile ON users
    FOR SELECT
    USING (
        supabase_user_id = get_current_user_id()
        OR EXISTS (
            SELECT 1 FROM business_members bm
            JOIN businesses b ON bm.business_id = b.id
            WHERE bm.user_id = users.id
            AND bm.is_active = true
            AND is_business_member(b.id, get_current_user_id())
        )
    );

-- Users can update their own profile
CREATE POLICY users_update_own_profile ON users
    FOR UPDATE
    USING (supabase_user_id = get_current_user_id())
    WITH CHECK (supabase_user_id = get_current_user_id());

-- Business owners/admins can manage users in their business
CREATE POLICY users_business_management ON users
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM business_members bm
            JOIN businesses b ON bm.business_id = b.id
            WHERE bm.user_id = users.id
            AND bm.role IN ('owner', 'admin')
            AND is_business_member(b.id, get_current_user_id())
        )
    );

-- ============================================================================
-- BUSINESSES RLS POLICIES
-- ============================================================================

-- Users can view businesses they are members of
CREATE POLICY businesses_view_membership ON businesses
    FOR SELECT
    USING (
        is_business_member(id, get_current_user_id())
    );

-- Only owners can update/delete businesses
CREATE POLICY businesses_owner_management ON businesses
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM business_members bm
            WHERE bm.business_id = businesses.id
            AND bm.user_id = (
                SELECT id FROM users WHERE supabase_user_id = get_current_user_id()
            )
            AND bm.role = 'owner'
            AND bm.is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM business_members bm
            WHERE bm.business_id = businesses.id
            AND bm.user_id = (
                SELECT id FROM users WHERE supabase_user_id = get_current_user_id()
            )
            AND bm.role = 'owner'
            AND bm.is_active = true
        )
    );

-- ============================================================================
-- BUSINESS MEMBERS RLS POLICIES
-- ============================================================================

-- Users can view members of their businesses
CREATE POLICY business_members_view ON business_members
    FOR SELECT
    USING (
        is_business_member(business_id, get_current_user_id())
    );

-- Owners and admins can manage members
CREATE POLICY business_members_manage ON business_members
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM business_members bm
            WHERE bm.business_id = business_members.business_id
            AND bm.user_id = (
                SELECT id FROM users WHERE supabase_user_id = get_current_user_id()
            )
            AND bm.role IN ('owner', 'admin')
            AND bm.is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM business_members bm
            WHERE bm.business_id = business_members.business_id
            AND bm.user_id = (
                SELECT id FROM users WHERE supabase_user_id = get_current_user_id()
            )
            AND bm.role IN ('owner', 'admin')
            AND bm.is_active = true
        )
    );

-- ============================================================================
-- LEADS RLS POLICIES
-- ============================================================================

-- Users can view leads in their businesses (respecting soft delete)
CREATE POLICY leads_view ON leads
    FOR SELECT
    USING (
        is_business_member(business_id, get_current_user_id())
        AND (deleted_at IS NULL OR deleted_at IS NOT NULL)
    );

-- Users can insert leads in their businesses
CREATE POLICY leads_insert ON leads
    FOR INSERT
    WITH CHECK (
        is_business_member(business_id, get_current_user_id())
        AND deleted_at IS NULL
    );

-- Users can update leads in their businesses (soft delete handling)
CREATE POLICY leads_update ON leads
    FOR UPDATE
    USING (
        is_business_member(business_id, get_current_user_id())
    )
    WITH CHECK (
        is_business_member(business_id, get_current_user_id())
    );

-- Users can delete (soft delete) leads in their businesses
CREATE POLICY leads_delete ON leads
    FOR DELETE
    USING (
        is_business_member(business_id, get_current_user_id())
    );

-- ============================================================================
-- FOLLOWUPS RLS POLICIES
-- ============================================================================

-- Users can view followups in their businesses
CREATE POLICY followups_view ON followups
    FOR SELECT
    USING (
        is_business_member(business_id, get_current_user_id())
    );

-- Users can insert followups in their businesses
CREATE POLICY followups_insert ON followups
    FOR INSERT
    WITH CHECK (
        is_business_member(business_id, get_current_user_id())
    );

-- Users can update followups in their businesses
CREATE POLICY followups_update ON followups
    FOR UPDATE
    USING (
        is_business_member(business_id, get_current_user_id())
    )
    WITH CHECK (
        is_business_member(business_id, get_current_user_id())
    );

-- Users can delete followups in their businesses
CREATE POLICY followups_delete ON followups
    FOR DELETE
    USING (
        is_business_member(business_id, get_current_user_id())
    );

-- ============================================================================
-- NOTES RLS POLICIES
-- ============================================================================

-- Users can view notes in their businesses
CREATE POLICY notes_view ON notes
    FOR SELECT
    USING (
        is_business_member(business_id, get_current_user_id())
    );

-- Users can insert notes in their businesses
CREATE POLICY notes_insert ON notes
    FOR INSERT
    WITH CHECK (
        is_business_member(business_id, get_current_user_id())
    );

-- Users can update their own notes or if they are admin/owner
CREATE POLICY notes_update ON notes
    FOR UPDATE
    USING (
        is_business_member(business_id, get_current_user_id())
        AND (
            author_id = (SELECT id FROM users WHERE supabase_user_id = get_current_user_id())
            OR EXISTS (
                SELECT 1 FROM business_members bm
                WHERE bm.business_id = notes.business_id
                AND bm.user_id = (SELECT id FROM users WHERE supabase_user_id = get_current_user_id())
                AND bm.role IN ('owner', 'admin')
                AND bm.is_active = true
            )
        )
    )
    WITH CHECK (
        is_business_member(business_id, get_current_user_id())
    );

-- Users can delete their own notes or if they are admin/owner
CREATE POLICY notes_delete ON notes
    FOR DELETE
    USING (
        is_business_member(business_id, get_current_user_id())
        AND (
            author_id = (SELECT id FROM users WHERE supabase_user_id = get_current_user_id())
            OR EXISTS (
                SELECT 1 FROM business_members bm
                WHERE bm.business_id = notes.business_id
                AND bm.user_id = (SELECT id FROM users WHERE supabase_user_id = get_current_user_id())
                AND bm.role IN ('owner', 'admin')
                AND bm.is_active = true
            )
        )
    );

-- ============================================================================
-- COMMUNICATIONS RLS POLICIES
-- ============================================================================

-- Users can view communications in their businesses
CREATE POLICY communications_view ON communications
    FOR SELECT
    USING (
        is_business_member(business_id, get_current_user_id())
    );

-- Users can insert communications in their businesses
CREATE POLICY communications_insert ON communications
    FOR INSERT
    WITH CHECK (
        is_business_member(business_id, get_current_user_id())
    );

-- ============================================================================
-- REVIEWS RLS POLICIES
-- ============================================================================

-- Users can view reviews in their businesses
CREATE POLICY reviews_view ON reviews
    FOR SELECT
    USING (
        is_business_member(business_id, get_current_user_id())
    );

-- Users can insert reviews in their businesses
CREATE POLICY reviews_insert ON reviews
    FOR INSERT
    WITH CHECK (
        is_business_member(business_id, get_current_user_id())
    );

-- Users can update reviews in their businesses (for responses)
CREATE POLICY reviews_update ON reviews
    FOR UPDATE
    USING (
        is_business_member(business_id, get_current_user_id())
    )
    WITH CHECK (
        is_business_member(business_id, get_current_user_id())
    );

-- ============================================================================
-- AUDIT LOGS RLS POLICIES
-- ============================================================================

-- Only owners and admins can view audit logs
CREATE POLICY audit_logs_view ON audit_logs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM business_members bm
            WHERE bm.business_id = audit_logs.business_id
            AND bm.user_id = (
                SELECT id FROM users WHERE supabase_user_id = get_current_user_id()
            )
            AND bm.role IN ('owner', 'admin')
            AND bm.is_active = true
        )
    );

-- Audit logs are insert-only for regular operations (via triggers)
CREATE POLICY audit_logs_insert ON audit_logs
    FOR INSERT
    WITH CHECK (true);

-- No updates or deletes allowed on audit logs
-- (No policies needed as default is deny)

-- ============================================================================
-- 7. STORAGE SETUP
-- ============================================================================

-- Create storage buckets (execute these in Supabase Dashboard or via API)
-- Note: These are SQL representations; actual bucket creation may require Supabase UI/API

-- Insert storage buckets configuration
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('business-logos', 'business-logos', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/svg+xml']),
    ('user-avatars', 'user-avatars', true, 5242880, ARRAY['image/jpeg', 'image/png']),
    ('lead-attachments', 'lead-attachments', false, 10485760, ARRAY['image/jpeg', 'image/png', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
    ('communication-attachments', 'communication-attachments', false, 10485760, ARRAY['image/jpeg', 'image/png', 'application/pdf']),
    ('exports', 'exports', false, 52428800, ARRAY['application/pdf', 'text/csv', 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies for business-logos
CREATE POLICY "Business logos are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'business-logos');

CREATE POLICY "Business owners can upload logos"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'business-logos'
    AND EXISTS (
        SELECT 1 FROM businesses b
        WHERE b.logo_url LIKE '%' || storage.objects.name
        AND is_business_member(b.id, get_current_user_id())
        AND EXISTS (
            SELECT 1 FROM business_members bm
            WHERE bm.business_id = b.id
            AND bm.user_id = (SELECT id FROM users WHERE supabase_user_id = get_current_user_id())
            AND bm.role IN ('owner', 'admin')
            AND bm.is_active = true
        )
    )
);

-- Storage RLS Policies for user-avatars
CREATE POLICY "User avatars are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'user-avatars');

CREATE POLICY "Users can upload their own avatars"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'user-avatars'
    AND EXISTS (
        SELECT 1 FROM users u
        WHERE u.avatar_url LIKE '%' || storage.objects.name
        AND u.supabase_user_id = get_current_user_id()
    )
);

-- Storage RLS Policies for lead-attachments
CREATE POLICY "Lead attachments - authenticated users can view"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'lead-attachments'
    AND is_business_member(
        (SELECT l.business_id FROM leads l WHERE l.id::TEXT = (storage.objects.name)::TEXT LIMIT 1),
        get_current_user_id()
    )
);

CREATE POLICY "Lead attachments - business members can upload"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'lead-attachments'
    AND is_business_member(
        (SELECT l.business_id FROM leads l WHERE l.id::TEXT = (split_part(storage.objects.name, '/', 1))::UUID LIMIT 1),
        get_current_user_id()
    )
);

-- Storage RLS Policies for exports
CREATE POLICY "Exports - business members can view their exports"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'exports'
    AND is_business_member(
        (SELECT b.id FROM businesses b WHERE b.id::TEXT = (split_part(storage.objects.name, '/', 1))::UUID LIMIT 1),
        get_current_user_id()
    )
);

CREATE POLICY "Exports - business admins can create exports"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'exports'
    AND EXISTS (
        SELECT 1 FROM business_members bm
        WHERE bm.business_id = (split_part(storage.objects.name, '/', 1))::UUID
        AND bm.user_id = (SELECT id FROM users WHERE supabase_user_id = get_current_user_id())
        AND bm.role IN ('owner', 'admin')
        AND bm.is_active = true
    )
);

-- ============================================================================
-- 8. AUTHENTICATION SETUP HELPER FUNCTIONS
-- ============================================================================

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user_signup()
RETURNS TRIGGER AS $$
DECLARE
    new_user_id UUID;
BEGIN
    -- Create user record
    INSERT INTO users (supabase_user_id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', SPLIT_PART(NEW.email, '@', 1)),
        'staff'
    )
    RETURNING id INTO new_user_id;
    
    -- Log the signup
    INSERT INTO audit_logs (user_id, action, table_name, record_id, new_values)
    VALUES (new_user_id, 'user_signup', 'users', new_user_id, jsonb_build_object('email', NEW.email));
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to handle new user signup
CREATE TRIGGER trigger_handle_new_user_signup
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user_signup();

-- Function to create business and assign owner
CREATE OR REPLACE FUNCTION create_business_with_owner(
    p_business_name VARCHAR,
    p_business_type business_type,
    p_owner_email VARCHAR
)
RETURNS UUID AS $$
DECLARE
    v_business_id UUID;
    v_user_id UUID;
    v_slug VARCHAR;
BEGIN
    -- Get user ID
    SELECT id INTO v_user_id FROM users WHERE email = p_owner_email;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found with email: %', p_owner_email;
    END IF;
    
    -- Generate unique slug
    v_slug := generate_unique_slug(p_business_name);
    
    -- Create business
    INSERT INTO businesses (name, slug, business_type)
    VALUES (p_business_name, v_slug, p_business_type)
    RETURNING id INTO v_business_id;
    
    -- Add user as owner
    INSERT INTO business_members (business_id, user_id, role, joined_at, is_active)
    VALUES (v_business_id, v_user_id, 'owner', NOW(), true);
    
    -- Log the creation
    PERFORM create_audit_log(
        v_business_id,
        v_user_id,
        'business_created',
        'businesses',
        v_business_id,
        NULL,
        jsonb_build_object('name', p_business_name, 'type', p_business_type)
    );
    
    RETURN v_business_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to invite team member
CREATE OR REPLACE FUNCTION invite_team_member(
    p_business_id UUID,
    p_email VARCHAR,
    p_role user_role
)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
    v_inviter_id UUID;
    v_member_id UUID;
BEGIN
    -- Get inviter ID
    SELECT id INTO v_inviter_id FROM users WHERE supabase_user_id = get_current_user_id();
    
    IF v_inviter_id IS NULL THEN
        RAISE EXCEPTION 'Authenticated user not found';
    END IF;
    
    -- Check if inviter has permission
    IF NOT EXISTS (
        SELECT 1 FROM business_members
        WHERE business_id = p_business_id
        AND user_id = v_inviter_id
        AND role IN ('owner', 'admin')
        AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Insufficient permissions to invite members';
    END IF;
    
    -- Find or create user
    SELECT id INTO v_user_id FROM users WHERE email = p_email;
    
    IF v_user_id IS NULL THEN
        -- Create pending user record
        INSERT INTO users (email, full_name, role, is_active)
        VALUES (p_email, SPLIT_PART(p_email, '@', 1), p_role, false)
        RETURNING id INTO v_user_id;
    END IF;
    
    -- Create or update membership
    INSERT INTO business_members (business_id, user_id, role, invited_by, is_active)
    VALUES (p_business_id, v_user_id, p_role, v_inviter_id, true)
    ON CONFLICT (business_id, user_id) DO UPDATE
    SET role = p_role, is_active = true, updated_at = NOW()
    RETURNING id INTO v_member_id;
    
    -- Log the invitation
    PERFORM create_audit_log(
        p_business_id,
        v_inviter_id,
        'member_invited',
        'business_members',
        v_member_id,
        NULL,
        jsonb_build_object('email', p_email, 'role', p_role)
    );
    
    RETURN v_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 9. SEED DATA (Optional - for development/testing)
-- ============================================================================

-- Uncomment below for development seed data
-- DO $$
-- DECLARE
--     v_business_id UUID;
--     v_user_id UUID;
-- BEGIN
--     -- Create test business
--     INSERT INTO businesses (name, slug, business_type, description, city, state)
--     VALUES ('Acme Salon', 'acme-salon', 'salon', 'Premium hair and beauty salon', 'New York', 'NY')
--     RETURNING id INTO v_business_id;
--     
--     -- Create test user
--     INSERT INTO users (email, full_name, role)
--     VALUES ('owner@acmesalon.com', 'John Owner', 'owner')
--     RETURNING id INTO v_user_id;
--     
--     -- Link user to business
--     INSERT INTO business_members (business_id, user_id, role, joined_at)
--     VALUES (v_business_id, v_user_id, 'owner', NOW());
--     
--     -- Create sample leads
--     INSERT INTO leads (business_id, owner_id, first_name, last_name, email, phone_number, source, status)
--     VALUES 
--         (v_business_id, v_user_id, 'Jane', 'Doe', 'jane@example.com', '+1234567890', 'website', 'new'),
--         (v_business_id, v_user_id, 'Bob', 'Smith', 'bob@example.com', '+1234567891', 'referral', 'contacted');
-- END $$;

-- ============================================================================
-- 10. VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: Active leads with followup info
CREATE OR REPLACE VIEW active_leads_with_followups AS
SELECT 
    l.id,
    l.business_id,
    l.first_name,
    l.last_name,
    l.email,
    l.phone_number,
    l.source,
    l.status,
    l.priority,
    l.estimated_value,
    l.next_followup_at,
    l.followups_count,
    l.notes_count,
    l.created_at,
    u.full_name AS owner_name,
    f.title AS next_followup_title,
    f.scheduled_at AS next_followup_scheduled,
    f.method AS next_followup_method
FROM leads l
LEFT JOIN users u ON l.owner_id = u.id
LEFT JOIN LATERAL (
    SELECT title, scheduled_at, method
    FROM followups
    WHERE lead_id = l.id
    AND status = 'pending'
    ORDER BY scheduled_at ASC
    LIMIT 1
) f ON true
WHERE l.deleted_at IS NULL
AND l.status NOT IN ('lost', 'dead', 'won');

-- View: Business dashboard stats
CREATE OR REPLACE VIEW business_dashboard_stats AS
SELECT 
    b.id AS business_id,
    b.name AS business_name,
    COUNT(DISTINCT l.id) FILTER (WHERE l.deleted_at IS NULL) AS total_leads,
    COUNT(DISTINCT l.id) FILTER (WHERE l.status = 'new' AND l.deleted_at IS NULL) AS new_leads,
    COUNT(DISTINCT l.id) FILTER (WHERE l.status = 'won' AND l.deleted_at IS NULL) AS won_leads,
    COUNT(DISTINCT l.id) FILTER (WHERE l.status IN ('lost', 'dead') AND l.deleted_at IS NULL) AS lost_leads,
    SUM(l.estimated_value) FILTER (WHERE l.status = 'won' AND l.deleted_at IS NULL) AS total_revenue,
    AVG(l.estimated_value) FILTER (WHERE l.status = 'won' AND l.deleted_at IS NULL) AS avg_deal_size,
    COUNT(DISTINCT f.id) FILTER (WHERE f.status = 'pending') AS pending_followups,
    COUNT(DISTINCT r.id) FILTER (WHERE r.rating >= 4) AS positive_reviews,
    COUNT(DISTINCT r.id) FILTER (WHERE r.rating < 4) AS negative_reviews,
    AVG(r.rating) AS avg_rating
FROM businesses b
LEFT JOIN leads l ON b.id = l.business_id
LEFT JOIN followups f ON b.id = f.business_id
LEFT JOIN reviews r ON b.id = r.business_id
GROUP BY b.id, b.name;

-- View: User activity summary
CREATE OR REPLACE VIEW user_activity_summary AS
SELECT 
    u.id AS user_id,
    u.full_name,
    u.email,
    bm.business_id,
    b.name AS business_name,
    bm.role,
    COUNT(DISTINCT l.id) FILTER (WHERE l.owner_id = u.id AND l.deleted_at IS NULL) AS owned_leads,
    COUNT(DISTINCT f.id) FILTER (WHERE f.assigned_to = u.id) AS assigned_followups,
    COUNT(DISTINCT f.id) FILTER (WHERE f.assigned_to = u.id AND f.status = 'completed') AS completed_followups,
    COUNT(DISTINCT n.id) FILTER (WHERE n.author_id = u.id) AS created_notes,
    COUNT(DISTINCT c.id) FILTER (WHERE c.user_id = u.id) AS sent_communications,
    u.last_login_at,
    u.created_at
FROM users u
JOIN business_members bm ON u.id = bm.user_id
JOIN businesses b ON bm.business_id = b.id
LEFT JOIN leads l ON u.id = l.owner_id
LEFT JOIN followups f ON u.id = f.assigned_to
LEFT JOIN notes n ON u.id = n.author_id
LEFT JOIN communications c ON u.id = c.user_id
WHERE bm.is_active = true
GROUP BY u.id, u.full_name, u.email, bm.business_id, b.name, bm.role, u.last_login_at, u.created_at;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
