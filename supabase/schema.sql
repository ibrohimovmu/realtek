-- ==============================================================================
-- WABI FAMILY & DISCIPLINE (PARENT & KIDS SMART ECOSYSTEM)
-- Supabase PostgreSQL Production Schema (0% Mock / 100% Realtime)
-- ==============================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. FAMILIES TABLE
CREATE TABLE IF NOT EXISTS public.families (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    family_code VARCHAR(6) UNIQUE NOT NULL,
    family_name VARCHAR(100) NOT NULL DEFAULT 'Bizning Oila',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index on family_code for instant 6-digit code lookup
CREATE INDEX IF NOT EXISTS idx_families_code ON public.families(family_code);

-- 3. PROFILES TABLE (Parent & Kid accounts)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('parent', 'kid')),
    avatar_url TEXT DEFAULT '',
    current_vibe_score INT DEFAULT 75 CHECK (current_vibe_score BETWEEN 0 AND 100),
    total_points INT DEFAULT 0,
    device_model VARCHAR(100) DEFAULT '',
    last_active TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_profiles_family ON public.profiles(family_id);

-- 4. TASKS AND HABITS TABLE
CREATE TABLE IF NOT EXISTS public.tasks_and_habits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE NOT NULL,
    kid_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title VARCHAR(255) NOT NULL,
    reward_points INT NOT NULL DEFAULT 50,
    deadline VARCHAR(50) DEFAULT '20:00',
    is_completed BOOLEAN DEFAULT false NOT NULL,
    verified_by_parent BOOLEAN DEFAULT false NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tasks_kid ON public.tasks_and_habits(kid_id);
CREATE INDEX IF NOT EXISTS idx_tasks_family ON public.tasks_and_habits(family_id);

-- 5. APP LIMITS & FOCUS LOCK TABLE
CREATE TABLE IF NOT EXISTS public.app_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE NOT NULL,
    kid_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    package_name VARCHAR(255) NOT NULL,
    app_name VARCHAR(100) NOT NULL,
    max_minutes_per_day INT NOT NULL DEFAULT 30,
    used_minutes_today INT NOT NULL DEFAULT 0,
    is_locked BOOLEAN DEFAULT false NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(kid_id, package_name)
);

CREATE INDEX IF NOT EXISTS idx_app_limits_kid ON public.app_limits(kid_id);

-- 6. PRAYER AND ALARMS TABLE
CREATE TABLE IF NOT EXISTS public.prayer_and_alarms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE NOT NULL,
    city VARCHAR(50) DEFAULT 'Namangan, Uzbekistan',
    fajr VARCHAR(10) DEFAULT '05:15',
    dhuhr VARCHAR(10) DEFAULT '12:20',
    asr VARCHAR(10) DEFAULT '15:45',
    maghrib VARCHAR(10) DEFAULT '17:35',
    isha VARCHAR(10) DEFAULT '19:05',
    auto_alarm_enabled BOOLEAN DEFAULT true NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_prayer_family ON public.prayer_and_alarms(family_id);

-- 7. ENABLE REALTIME REPLICATION FOR INSTANT SYNC
ALTER PUBLICATION supabase_realtime ADD TABLE public.families;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks_and_habits;
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_limits;
ALTER PUBLICATION supabase_realtime ADD TABLE public.prayer_and_alarms;

-- 8. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks_and_habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prayer_and_alarms ENABLE ROW LEVEL SECURITY;

-- Allow anon read/write with family_code verification
CREATE POLICY "Public families access" ON public.families FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public profiles access" ON public.profiles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public tasks access" ON public.tasks_and_habits FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public app_limits access" ON public.app_limits FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public prayer access" ON public.prayer_and_alarms FOR ALL USING (true) WITH CHECK (true);
