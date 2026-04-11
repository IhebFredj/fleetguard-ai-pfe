-- ═══════════════════════════════════════════════════════════════
-- FleetGuard AI — Table obd_data complète
-- Compatible avec l'ESP32 ET l'application Flutter
-- ═══════════════════════════════════════════════════════════════

-- ⚠ ATTENTION: Ceci supprime et recrée la table (perte de données)
DROP TABLE IF EXISTS obd_data;

CREATE TABLE obd_data (
  id                    bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  created_at            timestamptz DEFAULT now(),
  
  -- Identifiant du camion (UUID de la table camions)
  camion                text,
  
  -- ── Moteur (données essentielles) ──
  rpm                   int4,
  temperature           int4,           -- Température moteur °C
  vitesse               int4,           -- Vitesse km/h
  
  -- ── Carburant ──
  carburant             int4,           -- Niveau carburant %
  conso_l_100           float4,         -- Consommation instantanée L/100km
  fuel_rate_lh          float4,         -- Débit carburant L/h
  fuel_consumed_total_l float4,         -- Consommation totale session (L)
  fuel_type             text,           -- Type: Diesel, Essence, GPL...
  fuel_pressure_kpa     float4,         -- Pression carburant kPa
  fuel_temp_c           float4,         -- Température carburant °C
  fuel_rail_kpa         float4,         -- Pression rampe commune kPa
  
  -- ── Pression et air ──
  pression_huile_bar    float4,         -- Pression huile (simulée)
  map_kpa               float4,         -- Pression admission (MAP) kPa
  maf_gps               float4,         -- Débit air massique g/s
  iat_c                 float4,         -- Température air admission °C
  baro_kpa              float4,         -- Pression barométrique kPa
  
  -- ── Conduite ──
  engine_load_pct       float4,         -- Charge moteur %
  tps_pct               float4,         -- Position papillon %
  pedal_pct             float4,         -- Position pédale accélérateur %
  distance_km           float4,         -- Distance parcourue session km
  odometer_km           float4,         -- Compteur kilométrique
  
  -- ── Températures ──
  oil_temp_c            float4,         -- Température huile °C
  ambient_temp_c        float4,         -- Température extérieure °C
  
  -- ── Électrique ──
  battery_voltage       float4,         -- Tension batterie V
  
  -- ── Diagnostic ──
  run_time_sec          int4,           -- Temps depuis démarrage (s)
  dist_since_dtc_km     int4,           -- Distance depuis reset DTC (km)
  dtc                   text[],         -- Codes défaut DTC
  status_ok             boolean,        -- Statut moteur OK
  
  -- ── Méta ──
  recorded_at           timestamptz     -- Timestamp du véhicule
);

-- ── Index pour requêtes rapides ──
CREATE INDEX idx_obd_data_camion ON obd_data(camion);
CREATE INDEX idx_obd_data_created_at ON obd_data(created_at DESC);

-- ── Sécurité Row Level Security ──
ALTER TABLE obd_data ENABLE ROW LEVEL SECURITY;

-- Autoriser l'insertion (ESP32 + App Flutter utilisent le rôle anon)
CREATE POLICY "Autoriser insertion ESP32 et App" 
ON obd_data 
FOR INSERT 
TO anon 
WITH CHECK (true);

-- Autoriser la lecture (pour l'app Flutter et le dashboard)
CREATE POLICY "Autoriser lecture publique" 
ON obd_data 
FOR SELECT 
TO anon 
USING (true);

-- Autoriser la mise à jour (pour corrections)
CREATE POLICY "Autoriser update" 
ON obd_data 
FOR UPDATE 
TO anon 
USING (true);
