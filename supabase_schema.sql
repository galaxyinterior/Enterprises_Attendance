-- ==========================================
-- ENTERPRISE ATTENDANCE SUPABASE SCHEMA
-- ==========================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. STORES
CREATE TABLE stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_code TEXT,
    store_name TEXT NOT NULL,
    owner_name TEXT,
    mobile_no TEXT,
    email TEXT,
    location TEXT,
    status TEXT DEFAULT 'active',
    address TEXT,
    open_time TEXT,
    close_time TEXT,
    punch_in_start TEXT,
    punch_in_end TEXT,
    punch_out_start TEXT,
    punch_out_end TEXT,
    tts_language TEXT DEFAULT 'en-US',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. PROFILES (Extends Auth Users for roles)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'kiosk', 'employee')),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    employee_id TEXT, -- Null if admin/kiosk
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. EMPLOYEES
CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    emp_id TEXT NOT NULL,
    name TEXT NOT NULL,
    department TEXT NOT NULL,
    phone TEXT DEFAULT 'N/A',
    dob TEXT DEFAULT 'N/A',
    joining_date TEXT DEFAULT 'N/A',
    duty_time TEXT DEFAULT 'N/A',
    duty_end_time TEXT DEFAULT 'N/A',
    designation TEXT DEFAULT 'N/A',
    email TEXT DEFAULT 'N/A',
    monthly_salary NUMERIC DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, emp_id)
);

-- 4. BIOMETRIC PROFILES (Isolated face data)
CREATE TABLE biometric_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    face_embedding JSONB NOT NULL,
    model_version TEXT DEFAULT 'mobilefacenet_v1',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. ATTENDANCE EVENTS (Raw punches)
CREATE TABLE attendance_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_event_id UUID UNIQUE NOT NULL, -- Idempotency key from device
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    device_id TEXT,
    event_type TEXT NOT NULL CHECK (event_type IN ('IN', 'OUT')),
    device_timestamp TIMESTAMPTZ NOT NULL,
    server_timestamp TIMESTAMPTZ DEFAULT NOW(),
    face_distance NUMERIC NOT NULL,
    confidence NUMERIC NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. ATTENDANCE DAILY (Derived states)
CREATE TABLE attendance_daily (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    first_in TIMESTAMPTZ,
    last_out TIMESTAMPTZ,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(employee_id, date)
);

-- 7. PAYROLL RECORDS
CREATE TABLE payroll_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    month_year TEXT NOT NULL, -- Format: MM-YYYY
    bonus NUMERIC DEFAULT 0.0,
    deduction NUMERIC DEFAULT 0.0,
    paid_absent_days INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(employee_id, month_year)
);

-- 8. DEVICES (Kiosk Management)
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    device_uuid TEXT UNIQUE NOT NULL,
    app_version TEXT,
    status TEXT DEFAULT 'offline',
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. NOTIFICATIONS
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    audio_path TEXT, -- Supabase Storage path
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- ==========================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================

ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE biometric_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Helper Function: Get User's Store ID
CREATE OR REPLACE FUNCTION get_user_store_id() RETURNS UUID AS $$
  SELECT store_id FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- Helper Function: Get User's Role
CREATE OR REPLACE FUNCTION get_user_role() RETURNS TEXT AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- POLICIES: STORES
CREATE POLICY "Users can read their own store" ON stores
  FOR SELECT USING (id = get_user_store_id());
  
CREATE POLICY "Admins can update their own store" ON stores
  FOR UPDATE USING (id = get_user_store_id() AND get_user_role() = 'admin');

-- POLICIES: PROFILES
CREATE POLICY "Users can read their own profile" ON profiles
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "Users can read profiles in their store" ON profiles
  FOR SELECT USING (store_id = get_user_store_id());

-- POLICIES: EMPLOYEES
CREATE POLICY "Users can read employees in their store" ON employees
  FOR SELECT USING (store_id = get_user_store_id());
  
CREATE POLICY "Admins and Kiosks can insert/update employees" ON employees
  FOR ALL USING (store_id = get_user_store_id() AND get_user_role() IN ('admin', 'kiosk'));
  
-- POLICIES: BIOMETRIC PROFILES (Strict)
CREATE POLICY "Kiosks can read biometrics for verification" ON biometric_profiles
  FOR SELECT USING (store_id = get_user_store_id() AND get_user_role() = 'kiosk');
  
CREATE POLICY "Admins and Kiosks can insert/update biometrics" ON biometric_profiles
  FOR ALL USING (store_id = get_user_store_id() AND get_user_role() IN ('admin', 'kiosk'));

-- POLICIES: ATTENDANCE EVENTS
CREATE POLICY "Users can read attendance in their store" ON attendance_events
  FOR SELECT USING (store_id = get_user_store_id());
  
CREATE POLICY "Admins and Kiosks can insert attendance" ON attendance_events
  FOR INSERT WITH CHECK (store_id = get_user_store_id() AND get_user_role() IN ('admin', 'kiosk'));

-- POLICIES: NOTIFICATIONS
CREATE POLICY "Users can read notifications in their store" ON notifications
  FOR SELECT USING (store_id = get_user_store_id());
  
CREATE POLICY "Admins can insert notifications" ON notifications
  FOR INSERT WITH CHECK (store_id = get_user_store_id() AND get_user_role() = 'admin');
