-- ============================================
-- LASTEY SAAS - SUPABASE DATABASE SCHEMA
-- Zero-Cost B2B2C Hostel Booking Platform
-- Haridwar & Rishikesh
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. ENUMS
-- ============================================

CREATE TYPE user_role AS ENUM ('ADMIN', 'OWNER', 'CUSTOMER');
CREATE TYPE verification_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
CREATE TYPE booking_status AS ENUM ('PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED');

-- ============================================
-- 2. USERS TABLE (Extends Supabase Auth)
-- ============================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    full_name TEXT NOT NULL,
    role user_role DEFAULT 'CUSTOMER',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for role-based queries
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_email ON users(email);

-- ============================================
-- 3. HOSTELS TABLE
-- ============================================

CREATE TABLE hostels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    address TEXT NOT NULL,
    city TEXT NOT NULL CHECK (city IN ('Haridwar', 'Rishikesh')),
    state TEXT DEFAULT 'Uttarakhand',
    pincode TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    total_beds INTEGER NOT NULL,
    amenities TEXT[], -- ['wifi', 'ac', 'parking', 'food', 'locker']
    images TEXT[], -- Supabase Storage URLs
    base_price DECIMAL(10, 2) NOT NULL,
    verification_status verification_status DEFAULT 'PENDING',
    admin_notes TEXT,
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for search and filtering
CREATE INDEX idx_hostels_owner ON hostels(owner_id);
CREATE INDEX idx_hostels_city ON hostels(city);
CREATE INDEX idx_hostels_verification ON hostels(verification_status);
CREATE INDEX idx_hostels_active ON hostels(is_active);

-- ============================================
-- 4. INVENTORY TABLE (Per Date Pricing & Availability)
-- ============================================

CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hostel_id UUID REFERENCES hostels(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_beds INTEGER NOT NULL,
    available_beds INTEGER NOT NULL,
    base_price DECIMAL(10, 2) NOT NULL,
    is_flash_sale BOOLEAN DEFAULT FALSE,
    flash_price DECIMAL(10, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(hostel_id, date)
);

-- Indexes for availability queries
CREATE INDEX idx_inventory_hostel_date ON inventory(hostel_id, date);
CREATE INDEX idx_inventory_flash_sale ON inventory(is_flash_sale) WHERE is_flash_sale = TRUE;
CREATE INDEX idx_inventory_availability ON inventory(available_beds) WHERE available_beds > 0;

-- ============================================
-- 5. BOOKINGS TABLE
-- ============================================

CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    hostel_id UUID REFERENCES hostels(id) ON DELETE CASCADE,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    beds_booked INTEGER NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    flash_sale_applied BOOLEAN DEFAULT FALSE,
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    status booking_status DEFAULT 'PENDING',
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    razorpay_signature TEXT,
    customer_name TEXT,
    customer_phone TEXT,
    customer_email TEXT,
    special_requests TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for booking queries
CREATE INDEX idx_bookings_customer ON bookings(customer_id);
CREATE INDEX idx_bookings_hostel ON bookings(hostel_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_dates ON bookings(check_in_date, check_out_date);

-- ============================================
-- 6. ADMIN_VERIFICATION_LOG TABLE
-- ============================================

CREATE TABLE admin_verification_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hostel_id UUID REFERENCES hostels(id) ON DELETE CASCADE,
    admin_id UUID REFERENCES users(id),
    action TEXT NOT NULL CHECK (action IN ('APPROVED', 'REJECTED')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_verification_log_hostel ON admin_verification_log(hostel_id);
CREATE INDEX idx_verification_log_admin ON admin_verification_log(admin_id);

-- ============================================
-- 7. NOTIFICATIONS TABLE
-- ============================================

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT CHECK (type IN ('VERIFICATION', 'BOOKING', 'FLASH_SALE', 'SYSTEM')),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- ============================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE hostels ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_verification_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users Policies
CREATE POLICY "Users can view their own data" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Admins can view all users" ON users
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'ADMIN')
    );

-- Hostels Policies
CREATE POLICY "Public can view approved hostels" ON hostels
    FOR SELECT USING (is_active = TRUE AND verification_status = 'APPROVED');

CREATE POLICY "Owners can view their own hostels" ON hostels
    FOR SELECT USING (owner_id = auth.uid());

CREATE POLICY "Owners can insert their hostels" ON hostels
    FOR INSERT WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Owners can update their hostels" ON hostels
    FOR UPDATE USING (owner_id = auth.uid());

CREATE POLICY "Admins can view all hostels" ON hostels
    FOR ALL USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'ADMIN')
    );

CREATE POLICY "Admins can update hostel verification" ON hostels
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'ADMIN')
    );

-- Inventory Policies
CREATE POLICY "Public can view available inventory" ON inventory
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM hostels 
            WHERE hostels.id = inventory.hostel_id 
            AND hostels.is_active = TRUE 
            AND hostels.verification_status = 'APPROVED'
        )
    );

CREATE POLICY "Owners can view their inventory" ON inventory
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM hostels 
            WHERE hostels.id = inventory.hostel_id 
            AND hostels.owner_id = auth.uid()
        )
    );

CREATE POLICY "Owners can update their inventory" ON inventory
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM hostels 
            WHERE hostels.id = inventory.hostel_id 
            AND hostels.owner_id = auth.uid()
        )
    );

CREATE POLICY "Owners can insert their inventory" ON inventory
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM hostels 
            WHERE hostels.id = inventory.hostel_id 
            AND hostels.owner_id = auth.uid()
        )
    );

-- Bookings Policies
CREATE POLICY "Customers can view their bookings" ON bookings
    FOR SELECT USING (customer_id = auth.uid());

CREATE POLICY "Customers can create bookings" ON bookings
    FOR INSERT WITH CHECK (customer_id = auth.uid());

CREATE POLICY "Owners can view bookings for their hostels" ON bookings
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM hostels 
            WHERE hostels.id = bookings.hostel_id 
            AND hostels.owner_id = auth.uid()
        )
    );

CREATE POLICY "Admins can view all bookings" ON bookings
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'ADMIN')
    );

-- Admin Verification Log Policies
CREATE POLICY "Admins can insert verification logs" ON admin_verification_log
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'ADMIN')
    );

CREATE POLICY "Admins can view verification logs" ON admin_verification_log
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'ADMIN')
    );

-- Notifications Policies
CREATE POLICY "Users can view their notifications" ON notifications
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "System can insert notifications" ON notifications
    FOR INSERT WITH CHECK (TRUE);

CREATE POLICY "Users can update their notifications" ON notifications
    FOR UPDATE USING (user_id = auth.uid());

-- ============================================
-- 9. FUNCTIONS & TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_hostels_updated_at BEFORE UPDATE ON hostels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_inventory_updated_at BEFORE UPDATE ON inventory
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to create default admin user (run once after deployment)
CREATE OR REPLACE FUNCTION create_default_admin(email_param TEXT, name_param TEXT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO users (email, full_name, role)
    VALUES (email_param, name_param, 'ADMIN')
    ON CONFLICT (email) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Function to initialize inventory for a hostel
CREATE OR REPLACE FUNCTION initialize_hostel_inventory(
    hostel_id_param UUID,
    start_date DATE,
    days INTEGER,
    base_price_param DECIMAL
)
RETURNS VOID AS $$
DECLARE
    current_date DATE;
    i INTEGER;
BEGIN
    FOR i IN 0..(days - 1) LOOP
        current_date := start_date + (i || ' days')::INTERVAL;
        INSERT INTO inventory (hostel_id, date, total_beds, available_beds, base_price)
        SELECT 
            hostel_id_param,
            current_date,
            h.total_beds,
            h.total_beds,
            base_price_param
        FROM hostels h
        WHERE h.id = hostel_id_param
        ON CONFLICT (hostel_id, date) DO NOTHING;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to activate flash sale
CREATE OR REPLACE FUNCTION activate_flash_sale(
    hostel_id_param UUID,
    target_date DATE
)
RETURNS BOOLEAN AS $$
DECLARE
    original_price DECIMAL;
    flash_price_val DECIMAL;
BEGIN
    -- Get base price
    SELECT base_price INTO original_price
    FROM inventory
    WHERE hostel_id = hostel_id_param AND date = target_date;
    
    IF original_price IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Calculate flash price (30% discount)
    flash_price_val := original_price * 0.7;
    
    -- Update inventory
    UPDATE inventory
    SET 
        is_flash_sale = TRUE,
        flash_price = flash_price_val,
        updated_at = NOW()
    WHERE hostel_id = hostel_id_param AND date = target_date;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to decrement available beds on booking
CREATE OR REPLACE FUNCTION decrement_available_beds(
    hostel_id_param UUID,
    check_in_param DATE,
    check_out_param DATE,
    beds_count INTEGER
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE inventory
    SET available_beds = available_beds - beds_count
    WHERE hostel_id = hostel_id_param
    AND date >= check_in_param
    AND date < check_out_param
    AND available_beds >= beds_count;
    
    IF FOUND THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 10. SEED DATA (Optional - For Development)
-- ============================================

-- Uncomment below to insert sample admin user
-- SELECT create_default_admin('admin@lastey.com', 'System Admin');

-- Sample hostel data (for testing)
-- INSERT INTO users (email, full_name, role) VALUES 
-- ('owner@test.com', 'Test Owner', 'OWNER'),
-- ('customer@test.com', 'Test Customer', 'CUSTOMER');

-- ============================================
-- END OF SCHEMA
-- ============================================
