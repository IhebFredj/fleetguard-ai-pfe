-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  FleetGuard AI – Supabase Tables & Fix                        ║
-- ║  Exécutez ce script dans : Supabase Dashboard → SQL Editor    ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ══════════════════════════════════════
-- ÉTAPE 1 : Supprimer TOUS les triggers/fonctions récursifs
-- (C'est la cause de l'erreur "stack depth limit exceeded")
-- ══════════════════════════════════════

-- Supprimer tous les triggers existants sur user_roles
DO $$
DECLARE
    trigger_rec RECORD;
BEGIN
    FOR trigger_rec IN
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'user_roles'
          AND event_object_schema = 'public'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.user_roles;', trigger_rec.trigger_name);
        RAISE NOTICE 'Trigger supprimé: %', trigger_rec.trigger_name;
    END LOOP;
END $$;

-- Supprimer tous les triggers existants sur drivers
DO $$
DECLARE
    trigger_rec RECORD;
BEGIN
    FOR trigger_rec IN
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'drivers'
          AND event_object_schema = 'public'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.drivers;', trigger_rec.trigger_name);
        RAISE NOTICE 'Trigger supprimé: %', trigger_rec.trigger_name;
    END LOOP;
END $$;

-- ══════════════════════════════════════
-- ÉTAPE 2 : Désactiver le RLS sur les tables concernées
-- (Pour éviter les politiques récursives)
-- ══════════════════════════════════════

ALTER TABLE IF EXISTS public.user_roles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.drivers DISABLE ROW LEVEL SECURITY;

-- Supprimer toutes les politiques RLS existantes sur user_roles
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname
        FROM pg_policies
        WHERE tablename = 'user_roles' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.user_roles;', pol.policyname);
        RAISE NOTICE 'Policy supprimée: %', pol.policyname;
    END LOOP;
END $$;

-- Supprimer toutes les politiques RLS existantes sur drivers
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname
        FROM pg_policies
        WHERE tablename = 'drivers' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.drivers;', pol.policyname);
        RAISE NOTICE 'Policy supprimée: %', pol.policyname;
    END LOOP;
END $$;

-- ══════════════════════════════════════
-- ÉTAPE 3 : Table user_roles
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'none',
    full_name TEXT,
    phone TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Ajouter les colonnes manquantes si la table existe déjà
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'user_roles' AND column_name = 'full_name'
    ) THEN
        ALTER TABLE public.user_roles ADD COLUMN full_name TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'user_roles' AND column_name = 'phone'
    ) THEN
        ALTER TABLE public.user_roles ADD COLUMN phone TEXT;
    END IF;
END $$;

-- Accès public pour l'API (anon + service_role)
GRANT ALL ON public.user_roles TO anon;
GRANT ALL ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;

-- ══════════════════════════════════════
-- ÉTAPE 4 : Table drivers
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    full_name TEXT NOT NULL DEFAULT 'Inconnu',
    email TEXT UNIQUE,
    phone TEXT DEFAULT '',
    license_number TEXT DEFAULT '',
    status TEXT DEFAULT 'active',
    rating DOUBLE PRECISION DEFAULT 0.0,
    truck_id TEXT,
    first_name TEXT,
    last_name TEXT,
    birth_date DATE,
    address TEXT,
    city TEXT,
    postal_code TEXT,
    country TEXT DEFAULT 'Tunisie',
    hire_date DATE,
    experience_years INTEGER DEFAULT 0,
    experience_months INTEGER DEFAULT 0,
    license_category TEXT,
    license_expiry_date DATE,
    salary_monthly DOUBLE PRECISION,
    rating_count INTEGER DEFAULT 0,
    trips_this_month INTEGER DEFAULT 0,
    total_trips INTEGER DEFAULT 0,
    total_mileage_km DOUBLE PRECISION DEFAULT 0,
    total_revenue DOUBLE PRECISION DEFAULT 0,
    truck_plate TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Accès public pour l'API
GRANT ALL ON public.drivers TO anon;
GRANT ALL ON public.drivers TO authenticated;
GRANT ALL ON public.drivers TO service_role;

-- ══════════════════════════════════════
-- ÉTAPE 5 : Table trips (voyages)
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.trips (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    truck_id TEXT,
    driver_id TEXT,
    departure TEXT,
    destination TEXT,
    departure_date TIMESTAMPTZ,
    arrival_date TIMESTAMPTZ,
    status TEXT DEFAULT 'planned',
    distance_km DOUBLE PRECISION DEFAULT 0,
    fuel_liters DOUBLE PRECISION DEFAULT 0,
    revenue DOUBLE PRECISION DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

GRANT ALL ON public.trips TO anon;
GRANT ALL ON public.trips TO authenticated;
GRANT ALL ON public.trips TO service_role;

-- ══════════════════════════════════════
-- ÉTAPE 6 : Table trip_validations
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.trip_validations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    trip_id UUID REFERENCES public.trips(id),
    truck_id TEXT,
    driver_id TEXT,
    departure TEXT,
    destination TEXT,
    distance_km DOUBLE PRECISION DEFAULT 0,
    fuel_liters DOUBLE PRECISION DEFAULT 0,
    validated_at TIMESTAMPTZ DEFAULT now(),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

GRANT ALL ON public.trip_validations TO anon;
GRANT ALL ON public.trip_validations TO authenticated;
GRANT ALL ON public.trip_validations TO service_role;

-- ══════════════════════════════════════
-- ÉTAPE 7 : Table trucks (véhicules)
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.trucks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    plate TEXT UNIQUE,
    brand TEXT,
    model TEXT,
    year INTEGER,
    type TEXT DEFAULT 'camion',
    status TEXT DEFAULT 'active',
    fuel_type TEXT DEFAULT 'diesel',
    mileage_km DOUBLE PRECISION DEFAULT 0,
    vin TEXT,
    gps_device_id TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

GRANT ALL ON public.trucks TO anon;
GRANT ALL ON public.trucks TO authenticated;
GRANT ALL ON public.trucks TO service_role;

-- ══════════════════════════════════════
-- ÉTAPE 8 : Table driver_documents
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.driver_documents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id UUID REFERENCES public.drivers(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL,
    document_url TEXT NOT NULL,
    file_name TEXT,
    uploaded_at TIMESTAMPTZ DEFAULT now()
);

GRANT ALL ON public.driver_documents TO anon;
GRANT ALL ON public.driver_documents TO authenticated;
GRANT ALL ON public.driver_documents TO service_role;

-- ══════════════════════════════════════
-- VÉRIFICATION FINALE
-- ══════════════════════════════════════

-- Lister les triggers restants (devrait être vide)
SELECT trigger_name, event_object_table, action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table IN ('user_roles', 'drivers');

-- Lister les politiques RLS restantes (devrait être vide)
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('user_roles', 'drivers');

-- Vérifier les colonnes de user_roles
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'user_roles'
ORDER BY ordinal_position;

-- Vérifier les colonnes de drivers
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'drivers'
ORDER BY ordinal_position;

-- ══════════════════════════════════════
-- ÉTAPE 9 : Tables Chef de Parc (Fond de Caisse)
-- ══════════════════════════════════════

-- Table Fond de Caisse
CREATE TABLE IF NOT EXISTS public.cash_funds (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chef_email TEXT NOT NULL,
    initial_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    current_balance DOUBLE PRECISION NOT NULL DEFAULT 0,
    alert_threshold DOUBLE PRECISION DEFAULT 50.0,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Table Dépenses
CREATE TABLE IF NOT EXISTS public.cash_expenses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    fund_id UUID REFERENCES public.cash_funds(id) ON DELETE CASCADE,
    truck_id TEXT,
    amount DOUBLE PRECISION NOT NULL,
    category TEXT NOT NULL DEFAULT 'autre',
    description TEXT,
    receipt_url TEXT,
    receipt_type TEXT,
    expense_date TIMESTAMPTZ DEFAULT now(),
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Table Rechargements
CREATE TABLE IF NOT EXISTS public.cash_reloads (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    fund_id UUID REFERENCES public.cash_funds(id) ON DELETE CASCADE,
    amount DOUBLE PRECISION NOT NULL,
    reloaded_by TEXT,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Permissions
GRANT ALL ON public.cash_funds TO anon, authenticated, service_role;
GRANT ALL ON public.cash_expenses TO anon, authenticated, service_role;
GRANT ALL ON public.cash_reloads TO anon, authenticated, service_role;

-- Désactiver RLS
ALTER TABLE public.cash_funds DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_expenses DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_reloads DISABLE ROW LEVEL SECURITY;

-- Créer le bucket de stockage pour les reçus
-- ⚠️ Exécuter cette ligne SEULE dans le SQL Editor si le bucket n'existe pas :
-- INSERT INTO storage.buckets (id, name, public) VALUES ('expense-receipts', 'expense-receipts', true)
-- ON CONFLICT (id) DO NOTHING;

-- ══════════════════════════════════════
-- ÉTAPE 10 : Table Notifications (alertes admin)
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    recipient_email TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT,
    type TEXT DEFAULT 'info',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

GRANT ALL ON public.notifications TO anon, authenticated, service_role;
ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;

-- Activer le mode Realtime pour la table notifications
begin;
  -- remove the table from the publication if it already exists there to avoid errors
  drop publication if exists supabase_realtime;
  create publication supabase_realtime;
commit;
alter publication supabase_realtime add table public.notifications;
