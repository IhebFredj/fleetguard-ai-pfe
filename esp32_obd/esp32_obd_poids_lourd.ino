/*
 * ═══════════════════════════════════════════════════════════════════════════
 * FleetGuard AI — ESP32 Firmware pour Camions Poids Lourds
 * ═══════════════════════════════════════════════════════════════════════════
 * 
 * Version :  2.0 — Heavy Duty (Poids Lourd)
 * 
 * Protocoles supportés :
 *   1. SAE J1939 CAN (29-bit ID, 250 kbaud) — Protocole principal poids lourds
 *   2. ISO 15765-4 CAN (OBD-II standard) — Fallback si J1939 non disponible
 * 
 * Véhicules compatibles :
 *   - Renault Trucks (T, D, C, K, Master, Premium)
 *   - Volvo Trucks (FH, FM, FMX, FE, FL)
 *   - Scania (R, S, G, P, L series)
 *   - MAN (TGX, TGS, TGM, TGL)
 *   - DAF (XF, XG, XG+, CF, LF)
 *   - Mercedes-Benz (Actros, Arocs, Atego, Econic)
 *   - IVECO (Stralis, Trakker, S-Way, Eurocargo)
 *   - Citroën Jumper / Fiat Ducato / Peugeot Boxer (VUL lourds)
 * 
 * Données lues spécifiques Poids Lourds :
 *   - PGN 61444 : RPM + Couple moteur (Engine Controller 1)
 *   - PGN 65265 : Vitesse véhicule (Cruise Control/Vehicle Speed)
 *   - PGN 65262 : Températures moteur (liquide refroidissement + carburant)
 *   - PGN 65263 : Niveaux & pressions (huile, liquide refroidissement, carburant)
 *   - PGN 65271 : Tension batterie (Vehicle Electrical Power)
 *   - PGN 65269 : Température ambiante & pression atmosphérique
 *   - PGN 65270 : Pression turbo + température échappement
 *   - PGN 65266 : Consommation carburant instantanée
 *   - PGN 65257 : Consommation totale carburant
 *   - PGN 65253 : Heures moteur
 *   - PGN 65248 : Odomètre (distance totale)
 *   - PGN 61443 : Position pédale accélérateur
 *   - PGN 65226 : DM1 — Codes défaut actifs (DTC)
 *   - PGN 65110 : Niveau AdBlue / DEF (Euro 6)
 *   - PGN 61445 : Rapport de boîte de vitesses
 *   - PGN 65249 : Retarder (frein moteur / ralentisseur)
 * 
 * Hardware : ESP32 DevKit + ELM327 Bluetooth (v1.5+ ou v2.1)
 * Branchement : OBD-II 16 broches (J1962) du camion → ELM327 → Bluetooth → ESP32
 * ═══════════════════════════════════════════════════════════════════════════
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <BluetoothSerial.h>
#include <string.h>
#include <ArduinoJson.h>

// ═══════════════════════════════════════════════════
// CONFIGURATION — À MODIFIER SELON VOTRE INSTALLATION
// ═══════════════════════════════════════════════════

// Wi-Fi (Point d'accès mobile ou WiFi dépôt)
const char* WIFI_SSID     = "Oppo Reno 8t 5g";
const char* WIFI_PASSWORD = "11111111";

// Supabase
const char* SUPABASE_URL  = "https://obwbtsgibyvbmslzrbwu.supabase.co";
const char* SUPABASE_KEY  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9id2J0c2dpYnl2Ym1zbHpyYnd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzMzM4MzUsImV4cCI6MjA4ODkwOTgzNX0.3rDQcB_ZGa0SJs-qSJ2AjmyxjZj3r2e4caiGZhzSoLE";
const char* TABLE_NAME    = "obd_data";

// ── Identifiant camion (doit correspondre à la table Supabase) ──
const char* CAMION_ID     = "255_tun_8550";

// ── Adresse MAC de l'adaptateur ELM327 Bluetooth ──
const uint8_t ELM_MAC[6]  = {0x00, 0x10, 0xCC, 0x4F, 0x36, 0x03};
const char* PIN_CODE      = "1234";

// ── Capacité réservoir Diesel (Litres) ──
// Poids lourds typiques : 200-600L (2 réservoirs possibles)
const float TANK_CAPACITY_L = 400.0;

// ── Capacité réservoir AdBlue/DEF (Litres) ──
const float ADBLUE_TANK_L   = 60.0;

// ── Intervalle d'envoi vers Supabase (ms) ──
const unsigned long UPLOAD_INTERVAL_MS = 5000;

// ═══════════════════════════════════════════════════
// PROTOCOLE DÉTECTÉ
// ═══════════════════════════════════════════════════

enum TruckProtocol {
  PROTO_UNKNOWN,
  PROTO_OBD2_CAN,     // Standard OBD-II (voitures / VUL)
  PROTO_J1939         // SAE J1939 (poids lourds)
};

TruckProtocol g_protocol = PROTO_UNKNOWN;

// ═══════════════════════════════════════════════════
// DONNÉES LIVE
// ═══════════════════════════════════════════════════

BluetoothSerial SerialBT;
bool elmConnected = false;

// Supported PIDs bitmask (for OBD-II fallback)
bool pidSupported[0x70] = {false};

// ── Données moteur (communes) ──
int    g_rpm              = 0;
float  g_speedKmh         = 0;
float  g_engineTempC      = -999;   // Température liquide de refroidissement
float  g_engineLoadPct    = -1;
float  g_torquePct        = -1;     // Couple moteur (% du couple max)
int    g_fuelLevelPct     = -1;
float  g_oilPressureBar   = -1;     // Pression huile moteur RÉELLE
float  g_oilTempC         = -999;   // Température huile moteur
float  g_batteryVoltage   = -1;
float  g_ambientTempC     = -999;
float  g_baroKpa          = -1;
float  g_pedalPct         = -1;     // Position pédale accélérateur

// ── Données spécifiques Poids Lourds ──
float  g_turboPressureKpa = -1;     // Pression de suralimentation (turbo)
float  g_exhaustTempC     = -999;   // Température gaz d'échappement
float  g_coolantLevelPct  = -1;     // Niveau liquide de refroidissement
float  g_coolantPressKpa  = -1;     // Pression circuit refroidissement
int    g_adBlueLevelPct   = -1;     // Niveau AdBlue/DEF (Euro 6)
float  g_engineHours      = -1;     // Heures moteur totales
float  g_odometerKm       = -1;     // Compteur kilométrique total
int    g_gearCurrent      = -127;   // Rapport de boîte engagé (-1=R, 0=N, 1-16)
float  g_retarderPct      = -1;     // Position ralentisseur/frein moteur (%)
float  g_fuelTempC        = -999;   // Température du carburant

// ── Consommation ──
float  g_fuelRateLh       = -1;     // Débit instantané (L/h)
float  g_fuelTotalL       = -1;     // Consommation cumulée depuis usine (L)
float  g_consoLPer100     = 0;      // Consommation instantanée (L/100km)
float  g_fuelConsumedL    = 0;      // Session consommée (L)
float  g_distanceKm       = 0;      // Session distance (km)
float  g_estimatedFuelPct = 50.0;   // Estimation si pas de capteur
bool   g_fuelPidSupported = false;

// ── Données auxiliaires OBD-II (fallback) ──
float  g_mafGps           = -1;
float  g_tpsPct           = -1;
float  g_iatC             = -999;
float  g_mapKpa           = -1;
float  g_fuelPressureKpa  = -1;

// ── Diagnostics (DTC) ──
bool   g_milOn            = false;
int    g_dtcCount         = 0;
String g_dtcCodes         = "";
String g_pendingDtcCodes  = "";

// ── Timing ──
unsigned long g_lastPollMs     = 0;
unsigned long g_lastUploadMs   = 0;
unsigned long g_lastTickMs     = 0;
unsigned long g_lastDashboardMs= 0;
int           g_pollCycle      = 0;

// ── Constantes carburant Diesel ──
float AFR     = 14.5;
float DENSITY = 0.835;

// ── J1939 state ──
int g_j1939FailCount = 0;

// ═══════════════════════════════════════════════════
// ELM327 COMMUNICATION (identique véhicule léger)
// ═══════════════════════════════════════════════════

String elmRequest(const String& cmd, unsigned long timeoutMs = 2000) {
  while (SerialBT.available()) SerialBT.read();
  SerialBT.print(cmd + "\r");
  
  String response = "";
  unsigned long start = millis();
  while ((millis() - start) < timeoutMs) {
    if (SerialBT.available()) {
      char c = SerialBT.read();
      if (c == '>') break;
      if (c != '\0') response += c;
    }
    delay(1);
  }
  response.trim();
  return response;
}

int parseHex(const String& s) {
  return (int)strtol(s.c_str(), NULL, 16);
}

bool isNoData(const String& resp) {
  String r = resp;
  r.toUpperCase();
  return r.indexOf("NO DATA") >= 0 || r.indexOf("ERROR") >= 0 || r.indexOf("UNABLE") >= 0;
}

// ═══════════════════════════════════════════════════
// MODE 01 PARSER (pour fallback OBD-II standard)
// ═══════════════════════════════════════════════════

int parseMode01(const String& resp, const String& pidHex, int* data, int maxBytes) {
  String cleaned = resp;
  cleaned.replace("\r", " ");
  cleaned.replace("\n", " ");
  cleaned.replace(">", " ");
  cleaned.replace(":", " ");
  cleaned.toUpperCase();
  cleaned.trim();
  
  String target41 = "41 " + pidHex;
  target41.toUpperCase();
  
  int idx = cleaned.indexOf(target41);
  if (idx < 0) {
    String targetNoSpace = "41" + pidHex;
    targetNoSpace.toUpperCase();
    idx = cleaned.indexOf(targetNoSpace);
    if (idx >= 0) idx += targetNoSpace.length();
    else return 0;
  } else {
    idx += target41.length();
  }
  
  String remainder = cleaned.substring(idx);
  remainder.trim();
  
  int count = 0;
  int pos = 0;
  while (count < maxBytes && pos < (int)remainder.length()) {
    while (pos < (int)remainder.length() && remainder[pos] == ' ') pos++;
    if (pos + 1 >= (int)remainder.length()) break;
    
    String byteStr = remainder.substring(pos, pos + 2);
    bool validHex = true;
    for (int i = 0; i < 2; i++) {
      char c = byteStr[i];
      if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F'))) {
        validHex = false;
        break;
      }
    }
    if (!validHex) break;
    
    data[count++] = parseHex(byteStr);
    pos += 2;
  }
  return count;
}

// ═══════════════════════════════════════════════════
// J1939 PGN PARSER
// ═══════════════════════════════════════════════════
// 
// En mode J1939, l'ELM327 utilise la commande ATMP (Monitor PGN)
// pour écouter un PGN spécifique sur le bus CAN.
//
// Réponse typique: "6 00FEEE 00 A0 32 FF FF FF FF FF"
//   - 6 = priorité
//   - 00FEEE = PGN (Engine Temp 1)
//   - Octets de données (8 bytes max)
//
// Pour les PGN broadcast (la majorité), on utilise ATMP xxxx
// Pour demander un PGN spécifiquement, on envoie une requête EA00

// Extraire les octets de données d'une réponse J1939
int parseJ1939(const String& resp, int* data, int maxBytes) {
  String cleaned = resp;
  cleaned.replace("\r", " ");
  cleaned.replace("\n", " ");
  cleaned.replace(">", " ");
  cleaned.toUpperCase();
  cleaned.trim();
  
  if (isNoData(cleaned)) return 0;
  
  // Trouver les octets de données
  // Format: [priorité] [PGN hex] [data bytes...]
  // ou juste les data bytes directement selon le mode
  
  // Tokeniser
  String tokens[20];
  int tokCount = 0;
  int pos = 0;
  while (pos < (int)cleaned.length() && tokCount < 20) {
    while (pos < (int)cleaned.length() && cleaned[pos] == ' ') pos++;
    int start = pos;
    while (pos < (int)cleaned.length() && cleaned[pos] != ' ') pos++;
    if (pos > start) {
      tokens[tokCount++] = cleaned.substring(start, pos);
    }
  }
  
  // Les données en J1939 commencent après l'en-tête PGN
  // Chercher le premier octet de données valide (2 chars hex)
  int dataStart = 0;
  
  // Si le premier token est > 2 chars, c'est probablement le PGN header
  for (int i = 0; i < tokCount; i++) {
    if (tokens[i].length() == 2) {
      dataStart = i;
      break;
    }
    if (tokens[i].length() > 4) {
      // C'est le PGN/header, les données suivent
      dataStart = i + 1;
    }
  }
  
  int count = 0;
  for (int i = dataStart; i < tokCount && count < maxBytes; i++) {
    if (tokens[i].length() == 2) {
      bool validHex = true;
      for (int j = 0; j < 2; j++) {
        char c = tokens[i][j];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F'))) {
          validHex = false;
          break;
        }
      }
      if (validHex) {
        data[count++] = parseHex(tokens[i]);
      }
    }
  }
  return count;
}

// Monitorer un PGN J1939 spécifique
// pgnHex: ex "FEEE" pour Engine Temp (PGN 65262)
// Timeout: temps max d'attente du broadcast
String monitorPGN(const String& pgnHex, unsigned long timeoutMs = 1500) {
  String cmd = "ATMP " + pgnHex;
  
  // Flush
  while (SerialBT.available()) SerialBT.read();
  
  SerialBT.print(cmd + "\r");
  
  String response = "";
  unsigned long start = millis();
  bool gotData = false;
  
  while ((millis() - start) < timeoutMs) {
    if (SerialBT.available()) {
      char c = SerialBT.read();
      if (c == '>') { gotData = true; break; }
      if (c == '\r' || c == '\n') {
        if (response.length() > 3 && !isNoData(response)) {
          gotData = true;
          // On a reçu une ligne de données, on peut arrêter
          // Envoyer un caractère pour arrêter le moniteur
          SerialBT.print("\r");
          delay(100);
          // Flush le reste
          while (SerialBT.available()) SerialBT.read();
          break;
        }
      }
      if (c != '\0') response += c;
    }
    delay(1);
  }
  
  // Si timeout, arrêter le moniteur
  if (!gotData) {
    SerialBT.print("\r");
    delay(100);
    while (SerialBT.available()) SerialBT.read();
  }
  
  response.trim();
  return response;
}

// ═══════════════════════════════════════════════════
// ELM327 INITIALIZATION + PROTOCOL AUTO-DETECTION
// ═══════════════════════════════════════════════════

bool initELM327() {
  Serial.println("[ELM] Initialisation adaptateur OBD...");
  
  delay(500);
  while (SerialBT.available()) SerialBT.read();
  
  String r;
  
  // Reset complet
  r = elmRequest("ATZ", 5000);
  Serial.println("[ELM] ATZ -> " + r);
  delay(1500);
  while (SerialBT.available()) SerialBT.read();
  
  // Configuration de base
  elmRequest("ATE0", 1500);   // Echo off
  elmRequest("ATL0", 1500);   // Linefeeds off
  elmRequest("ATH0", 1500);   // Headers off
  elmRequest("ATS1", 1500);   // Spaces ON
  elmRequest("ATAT1", 1500);  // Adaptive timing
  elmRequest("ATST64", 1500); // Timeout 400ms
  
  // Identifier l'adaptateur
  r = elmRequest("ATI", 1500);
  Serial.println("[ELM] Adaptateur: " + r);
  
  // ══════════════════════════════════════════════════
  // PHASE 1 : Tenter le protocole J1939 (poids lourds)
  // ══════════════════════════════════════════════════
  Serial.println();
  Serial.println("[PROTO] ═══ Détection du protocole camion ═══");
  Serial.println("[PROTO] Phase 1: Tentative SAE J1939 (Poids Lourd)...");
  
  // Protocole A = SAE J1939 CAN (29-bit, 250 kbaud)
  r = elmRequest("ATSP A", 2000);
  Serial.println("[PROTO] ATSP A -> " + r);
  
  // Configurer les timeouts J1939
  elmRequest("ATJTM5", 1000);  // J1939 timeout multiplier (max)
  
  // Tester en lisant le RPM moteur (PGN F004 = Electronic Engine Controller 1)
  // C'est le PGN le plus universellement diffusé sur tous les poids lourds
  delay(300);
  r = monitorPGN("F004", 3000);
  Serial.println("[PROTO] PGN F004 (RPM) -> [" + r + "]");
  
  if (!isNoData(r) && r.length() > 4) {
    // ✅ J1939 détecté !
    g_protocol = PROTO_J1939;
    Serial.println("[PROTO] ✅ PROTOCOLE J1939 DÉTECTÉ ! (Camion Poids Lourd)");
    Serial.println("[PROTO] Mode: SAE J1939 CAN 29-bit 250kbaud");
    
    // Reporter le premier RPM lu
    int d[8];
    int n = parseJ1939(r, d, 8);
    if (n >= 4) {
      int rpm = ((d[3] * 256) + d[2]) / 8;  // SPN 190 : bytes 4-3, résolution 0.125 tr/min
      Serial.printf("[PROTO] Premier RPM lu: %d tr/min\n", rpm);
    }
    return true;
  }
  
  // ══════════════════════════════════════════════════
  // PHASE 2 : Fallback OBD-II standard (véhicules légers/VUL)
  // ══════════════════════════════════════════════════
  Serial.println("[PROTO] J1939 non disponible sur ce véhicule.");
  Serial.println("[PROTO] Phase 2: Tentative OBD-II standard (ISO 15765-4 CAN)...");
  
  // Essayer tous les protocoles OBD-II CAN (les plus courants d'abord)
  const char* protocols[] = {"6", "7", "8", "9", "0", "1", "2", "3", "4", "5"};
  const char* protoNames[] = {
    "CAN 11/500k", "CAN 29/500k", "CAN 11/250k", "CAN 29/250k",
    "Auto", "J1850 PWM", "J1850 VPW", "ISO 9141-2", "KWP 5bd", "KWP Fast"
  };
  
  for (int p = 0; p < 10; p++) {
    String setProto = "ATSP" + String(protocols[p]);
    elmRequest(setProto, 2000);
    delay(300);
    
    r = elmRequest("0100", 8000);
    Serial.printf("[PROTO] Protocole %s (%s) -> [%.40s...]\n", 
                  protocols[p], protoNames[p], r.c_str());
    
    if (!isNoData(r) && r.indexOf("41") >= 0) {
      g_protocol = PROTO_OBD2_CAN;
      Serial.printf("[PROTO] ✅ PROTOCOLE OBD-II DÉTECTÉ ! (%s)\n", protoNames[p]);
      return true;
    }
  }
  
  // Aucun protocole trouvé — on continue quand même en OBD-II
  Serial.println("[PROTO] ⚠ Aucun protocole détecté. Mode dégradé OBD-II.");
  g_protocol = PROTO_OBD2_CAN;
  return true;
}

// ═══════════════════════════════════════════════════
// SUPPORTED PIDS DETECTION (OBD-II only)
// ═══════════════════════════════════════════════════

void detectSupportedPids() {
  if (g_protocol == PROTO_J1939) {
    Serial.println("[PID] Mode J1939 — Pas de détection PID (utilise PGN)");
    return;
  }
  
  Serial.println("[PID] Détection des PIDs supportés (OBD-II)...");
  
  int totalFound = 0;
  const char* queries[] = {"0100", "0120", "0140", "0160"};
  const char* pids[]    = {"00",   "20",   "40",   "60"};
  int offsets[]          = {0,      0x20,   0x40,   0x60};
  
  for (int q = 0; q < 4; q++) {
    String resp = elmRequest(queries[q], 5000);
    if (isNoData(resp)) continue;
    
    int data[4];
    int n = parseMode01(resp, pids[q], data, 4);
    
    if (n == 4) {
      uint32_t mask = ((uint32_t)data[0] << 24) | ((uint32_t)data[1] << 16) | 
                      ((uint32_t)data[2] << 8)  | (uint32_t)data[3];
      for (int i = 0; i < 32; i++) {
        if (mask & (1UL << (31 - i))) {
          int pid = offsets[q] + i + 1;
          if (pid < 0x70) {
            pidSupported[pid] = true;
            totalFound++;
          }
        }
      }
    }
    
    int nextPid = offsets[q] + 0x20;
    if (nextPid < 0x70 && !pidSupported[nextPid]) break;
  }
  
  if (totalFound == 0) {
    Serial.println("[PID] ⚠ Aucun PID détecté. Activation des PIDs de base.");
    pidSupported[0x04] = true;  pidSupported[0x05] = true;
    pidSupported[0x0B] = true;  pidSupported[0x0C] = true;
    pidSupported[0x0D] = true;  pidSupported[0x0F] = true;
    pidSupported[0x10] = true;  pidSupported[0x11] = true;
    pidSupported[0x1F] = true;  pidSupported[0x2F] = true;
    pidSupported[0x42] = true;  pidSupported[0x46] = true;
    g_fuelPidSupported = true;
    totalFound = 12;
  }
  
  g_fuelPidSupported = pidSupported[0x2F];
  Serial.printf("[PID] Total supportés: %d\n", totalFound);
}

// ═══════════════════════════════════════════════════
// J1939 PGN READERS — Données spécifiques poids lourds
// ═══════════════════════════════════════════════════
//
// Référence: SAE J1939-71 (Vehicle Application Layer)
// Chaque PGN contient des SPNs (Suspect Parameter Numbers)
// Résolution et offset selon la norme J1939

// ── PGN 61444 (0xF004) — Electronic Engine Controller 1 ──
// SPN 190: RPM     → Bytes 4-3, résolution 0.125 tr/min
// SPN 513: Torque  → Byte 3, résolution 1%, offset -125%
void j1939_ReadEngineController1() {
  String r = monitorPGN("F004", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 4) {
    // SPN 190: Engine Speed (RPM)
    int rawRpm = (d[3] << 8) | d[2];
    if (rawRpm != 0xFFFF) {
      g_rpm = rawRpm / 8;  // Résolution: 0.125 tr/min
    }
    
    // SPN 513: Actual Engine Percent Torque
    if (d[2] != 0xFF) {
      g_torquePct = d[2] - 125.0;  // Offset: -125%
    }
  }
}

// ── PGN 65265 (0xFEF1) — Cruise Control / Vehicle Speed ──
// SPN 84: Vehicle Speed → Bytes 2-1, résolution 1/256 km/h
void j1939_ReadVehicleSpeed() {
  String r = monitorPGN("FEF1", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 2) {
    int rawSpeed = (d[1] << 8) | d[0];
    if (rawSpeed != 0xFFFF) {
      g_speedKmh = rawSpeed / 256.0;  // Résolution: 1/256 km/h
    }
  }
}

// ── PGN 65262 (0xFEEE) — Engine Temperature 1 ──
// SPN 110: Engine Coolant Temp → Byte 1, résolution 1°C, offset -40
// SPN 175: Engine Oil Temp     → Bytes 4-3, résolution 1/16°C, offset -273
// SPN 174: Fuel Temperature    → Byte 2, résolution 1°C, offset -40
void j1939_ReadEngineTemp() {
  String r = monitorPGN("FEEE", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 1) {
    // SPN 110: Coolant Temperature
    if (d[0] != 0xFF) {
      g_engineTempC = d[0] - 40.0;
    }
  }
  if (n >= 2) {
    // SPN 174: Fuel Temperature
    if (d[1] != 0xFF) {
      g_fuelTempC = d[1] - 40.0;
    }
  }
  if (n >= 4) {
    // SPN 175: Oil Temperature (16-bit)
    int rawOil = (d[3] << 8) | d[2];
    if (rawOil != 0xFFFF) {
      g_oilTempC = (rawOil * 0.03125) - 273.0;  // Résolution: 1/32°C, offset -273
    }
  }
}

// ── PGN 65263 (0xFEEF) — Engine Fluid Level/Pressure ──
// SPN 94:  Fuel Delivery Pressure  → Byte 1, résolution 4 kPa
// SPN 22:  Engine Oil Pressure     → Byte 4, résolution 4 kPa
// SPN 111: Coolant Level           → Byte 3, résolution 0.4%
// SPN 109: Coolant Pressure        → Byte 2, résolution 2 kPa
// SPN 98:  Engine Oil Level        → Byte 4, résolution 0.4%
void j1939_ReadFluidLevels() {
  String r = monitorPGN("FEEF", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  
  if (n >= 4) {
    // SPN 94: Fuel Delivery Pressure
    if (d[0] != 0xFF) {
      g_fuelPressureKpa = d[0] * 4.0;
    }
    // SPN 109: Coolant Pressure
    if (d[1] != 0xFF) {
      g_coolantPressKpa = d[1] * 2.0;
    }
    // SPN 111: Coolant Level
    if (d[2] != 0xFF) {
      g_coolantLevelPct = d[2] * 0.4;
    }
    // SPN 22: Engine Oil Pressure (CRUCIAL pour l'IA !)
    if (d[3] != 0xFF) {
      g_oilPressureBar = (d[3] * 4.0) / 100.0;  // kPa → bar
    }
  }
}

// ── PGN 65271 (0xFEF7) — Vehicle Electrical Power ──
// SPN 168: Battery Voltage → Bytes 5-4, résolution 0.05V
void j1939_ReadElectricalPower() {
  String r = monitorPGN("FEF7", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 5) {
    int rawV = (d[4] << 8) | d[3];
    if (rawV != 0xFFFF) {
      g_batteryVoltage = rawV * 0.05;  // Résolution: 0.05V
    }
  }
}

// ── PGN 65269 (0xFEF5) — Ambient Conditions ──
// SPN 171: Ambient Air Temp → Bytes 4-3, résolution 1/32°C, offset -273
// SPN 108: Barometric Press → Byte 1, résolution 0.5 kPa
void j1939_ReadAmbientConditions() {
  String r = monitorPGN("FEF5", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 1) {
    // SPN 108: Barometric Pressure
    if (d[0] != 0xFF) {
      g_baroKpa = d[0] * 0.5;
    }
  }
  if (n >= 4) {
    // SPN 171: Ambient Air Temperature
    int rawTemp = (d[3] << 8) | d[2];
    if (rawTemp != 0xFFFF) {
      g_ambientTempC = (rawTemp * 0.03125) - 273.0;
    }
  }
}

// ── PGN 65270 (0xFEF6) — Inlet/Exhaust Conditions 1 ──
// SPN 105: Intake Manifold Temp → Byte 3, résolution 1°C, offset -40
// SPN 102: Boost Pressure       → Bytes 2-1, résolution 0.125 kPa (2 bytes) ou byte 1 * 2kPa
// SPN 173: Exhaust Gas Temp     → Bytes 5-4, résolution 1/32°C, offset -273
void j1939_ReadInletExhaust() {
  String r = monitorPGN("FEF6", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  
  if (n >= 2) {
    // SPN 102: Boost Pressure (Turbo)
    int rawBoost = (d[1] << 8) | d[0];
    if (rawBoost != 0xFFFF) {
      g_turboPressureKpa = rawBoost * 0.125;
    }
  }
  if (n >= 3) {
    // SPN 105: Intake Manifold Temperature
    if (d[2] != 0xFF) {
      g_iatC = d[2] - 40.0;
    }
  }
  if (n >= 5) {
    // SPN 173: Exhaust Gas Temperature
    int rawExh = (d[4] << 8) | d[3];
    if (rawExh != 0xFFFF) {
      g_exhaustTempC = (rawExh * 0.03125) - 273.0;
    }
  }
}

// ── PGN 65266 (0xFEF2) — Fuel Economy ──
// SPN 183: Fuel Rate → Bytes 1-0, résolution 0.05 L/h
// SPN 184: Instantaneous Fuel Economy → Bytes 3-2, résolution 1/512 km/L
void j1939_ReadFuelEconomy() {
  String r = monitorPGN("FEF2", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 2) {
    // SPN 183: Fuel Rate (L/h)
    int rawRate = (d[1] << 8) | d[0];
    if (rawRate != 0xFFFF) {
      g_fuelRateLh = rawRate * 0.05;  // Résolution: 0.05 L/h
    }
  }
  if (n >= 4) {
    // SPN 184: Instantaneous Fuel Economy (km/L → L/100km)
    int rawEco = (d[3] << 8) | d[2];
    if (rawEco != 0xFFFF && rawEco > 0) {
      float kmPerL = rawEco / 512.0;
      if (kmPerL > 0) {
        g_consoLPer100 = 100.0 / kmPerL;
      }
    }
  }
}

// ── PGN 65257 (0xFEE9) — Total Fuel Consumed ──
// SPN 250: Total Fuel Used → Bytes 4-0, résolution 0.5 L
void j1939_ReadTotalFuel() {
  String r = monitorPGN("FEE9", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 4) {
    uint32_t rawFuel = ((uint32_t)d[3] << 24) | ((uint32_t)d[2] << 16) |
                       ((uint32_t)d[1] << 8) | d[0];
    if (rawFuel != 0xFFFFFFFF) {
      g_fuelTotalL = rawFuel * 0.5;  // Résolution: 0.5 L
    }
  }
}

// ── PGN 65263 + PGN 65276 → Fuel Level ──
// SPN 96: Fuel Level → Byte 2 de PGN 65276 (0xFEFC Dash Display), résolution 0.4%
void j1939_ReadFuelLevel() {
  String r = monitorPGN("FEFC", 2000);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 2) {
    // SPN 96: Fuel Level 1
    if (d[1] != 0xFF) {
      g_fuelLevelPct = (int)(d[1] * 0.4);
      g_fuelPidSupported = true;
    }
  }
}

// ── PGN 65253 (0xFEE5) — Engine Hours / Revolutions ──
// SPN 247: Engine Total Hours → Bytes 4-0, résolution 0.05 h
void j1939_ReadEngineHours() {
  String r = monitorPGN("FEE5", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 4) {
    uint32_t rawHours = ((uint32_t)d[3] << 24) | ((uint32_t)d[2] << 16) |
                        ((uint32_t)d[1] << 8) | d[0];
    if (rawHours != 0xFFFFFFFF) {
      g_engineHours = rawHours * 0.05;
    }
  }
}

// ── PGN 65248 (0xFEE0) — Vehicle Distance ──
// SPN 245: Total Vehicle Distance → Bytes 4-0, résolution 0.125 km
void j1939_ReadOdometer() {
  String r = monitorPGN("FEE0", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 4) {
    uint32_t rawDist = ((uint32_t)d[3] << 24) | ((uint32_t)d[2] << 16) |
                       ((uint32_t)d[1] << 8) | d[0];
    if (rawDist != 0xFFFFFFFF) {
      g_odometerKm = rawDist * 0.125;
    }
  }
}

// ── PGN 61443 (0xF003) — Electronic Engine Controller 2 ──
// SPN 91:  Accelerator Pedal Position → Byte 2, résolution 0.4%
// SPN 92:  Engine Load               → Byte 3, résolution 1%
void j1939_ReadEngineController2() {
  String r = monitorPGN("F003", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 2) {
    // SPN 91: Accelerator Pedal
    if (d[1] != 0xFF) {
      g_pedalPct = d[1] * 0.4;
    }
  }
  if (n >= 3) {
    // SPN 92: Percent Load at Current Speed
    if (d[2] != 0xFF) {
      g_engineLoadPct = d[2];
    }
  }
}

// ── PGN 61445 (0xF005) — Electronic Transmission Controller 2 ──
// SPN 524: Transmission Current Gear → Byte 4, offset -125
void j1939_ReadTransmission() {
  String r = monitorPGN("F005", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 4) {
    if (d[3] != 0xFF) {
      g_gearCurrent = d[3] - 125;  // -125=R, 0=N, 1-16=vitesses avant
    }
  }
}

// ── PGN 65110 (0xFE56) — Aftertreatment DEF Tank (AdBlue) ──
// SPN 1761: DEF Tank Level → Byte 1, résolution 0.4%
void j1939_ReadAdBlueLevel() {
  String r = monitorPGN("FE56", 2000);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 1) {
    if (d[0] != 0xFF) {
      g_adBlueLevelPct = (int)(d[0] * 0.4);
    }
  }
}

// ── PGN 65226 (0xFECA) — DM1: Active Diagnostic Trouble Codes ──
void j1939_ReadDM1() {
  String r = monitorPGN("FECA", 2000);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  
  if (n >= 2) {
    // Byte 1: MIL status (bits 7-6)
    g_milOn = (d[0] & 0xC0) != 0;
    
    // Les DTCs commencent à byte 3
    // Chaque DTC = 4 bytes (SPN 19bit + FMI 5bit + OC 7bit)
    g_dtcCount = 0;
    g_dtcCodes = "";
    
    if (n >= 6) {
      for (int i = 2; i + 3 < n; i += 4) {
        // SPN: bytes i, i+1, et bits 7-5 de i+2
        uint32_t spn = d[i] | (d[i+1] << 8) | ((d[i+2] & 0xE0) << 11);
        int fmi = d[i+2] & 0x1F;
        
        if (spn == 0 && fmi == 0) continue;
        if (spn == 0x7FFFF) continue;  // Not available
        
        if (g_dtcCodes.length() > 0) g_dtcCodes += ",";
        g_dtcCodes += "SPN" + String(spn) + "/FMI" + String(fmi);
        g_dtcCount++;
      }
    }
  }
  
  Serial.printf("[DTC] J1939 DM1 — MIL: %s, DTCs: %d\n", 
                g_milOn ? "ALLUMÉ" : "éteint", g_dtcCount);
  if (g_dtcCodes.length() > 0) {
    Serial.println("[DTC] Codes: " + g_dtcCodes);
  }
}

// ── PGN 65249 (0xFEE1) — Retarder (Frein moteur / Ralentisseur) ──
// SPN 520: Retarder Torque Mode → Byte 1
// SPN 521: Retarder Percent     → Byte 2, offset -125%
void j1939_ReadRetarder() {
  String r = monitorPGN("FEE1", 1500);
  if (isNoData(r)) return;
  
  int d[8];
  int n = parseJ1939(r, d, 8);
  if (n >= 2) {
    if (d[1] != 0xFF) {
      g_retarderPct = d[1] - 125.0;  // -125% à +125%
      if (g_retarderPct < 0) g_retarderPct = 0;
    }
  }
}

// ═══════════════════════════════════════════════════
// OBD-II PID READERS (Fallback pour VUL / véhicules légers)
// ═══════════════════════════════════════════════════

int readRPM_OBD() {
  if (!pidSupported[0x0C]) return -1;
  String r = elmRequest("010C", 800);
  int d[2];
  if (parseMode01(r, "0C", d, 2) == 2) return ((d[0] * 256) + d[1]) / 4;
  return -1;
}

float readSpeed_OBD() {
  if (!pidSupported[0x0D]) return -1;
  String r = elmRequest("010D", 800);
  int d[1];
  if (parseMode01(r, "0D", d, 1) == 1) return (float)d[0];
  return -1;
}

float readEngineTemp_OBD() {
  if (!pidSupported[0x05]) return -999;
  String r = elmRequest("0105", 800);
  int d[1];
  if (parseMode01(r, "05", d, 1) == 1) return d[0] - 40.0;
  return -999;
}

float readEngineLoad_OBD() {
  if (!pidSupported[0x04]) return -1;
  String r = elmRequest("0104", 800);
  int d[1];
  if (parseMode01(r, "04", d, 1) == 1) return (100.0 * d[0]) / 255.0;
  return -1;
}

float readMAF_OBD() {
  if (!pidSupported[0x10]) return -1;
  String r = elmRequest("0110", 800);
  int d[2];
  if (parseMode01(r, "10", d, 2) == 2) return ((d[0] * 256) + d[1]) / 100.0;
  return -1;
}

int readFuelLevel_OBD() {
  if (!pidSupported[0x2F]) return -1;
  String r = elmRequest("012F", 800);
  int d[1];
  if (parseMode01(r, "2F", d, 1) == 1) return (int)round((100.0 * d[0]) / 255.0);
  return -1;
}

float readFuelRate_OBD() {
  if (!pidSupported[0x5E]) return -1;
  String r = elmRequest("015E", 800);
  int d[2];
  if (parseMode01(r, "5E", d, 2) == 2) return ((d[0] * 256) + d[1]) / 20.0;
  return -1;
}

float readBatteryVoltage_OBD() {
  if (!pidSupported[0x42]) return -1;
  String r = elmRequest("0142", 800);
  int d[2];
  if (parseMode01(r, "42", d, 2) == 2) return ((d[0] * 256) + d[1]) / 1000.0;
  return -1;
}

float readAmbientTemp_OBD() {
  if (!pidSupported[0x46]) return -999;
  String r = elmRequest("0146", 800);
  int d[1];
  if (parseMode01(r, "46", d, 1) == 1) return d[0] - 40.0;
  return -999;
}

float readTPS_OBD() {
  if (!pidSupported[0x11]) return -1;
  String r = elmRequest("0111", 800);
  int d[1];
  if (parseMode01(r, "11", d, 1) == 1) return (100.0 * d[0]) / 255.0;
  return -1;
}

float readIAT_OBD() {
  if (!pidSupported[0x0F]) return -999;
  String r = elmRequest("010F", 800);
  int d[1];
  if (parseMode01(r, "0F", d, 1) == 1) return d[0] - 40.0;
  return -999;
}

float readMAP_OBD() {
  if (!pidSupported[0x0B]) return -1;
  String r = elmRequest("010B", 800);
  int d[1];
  if (parseMode01(r, "0B", d, 1) == 1) return (float)d[0];
  return -1;
}

float readOilTemp_OBD() {
  if (!pidSupported[0x5C]) return -999;
  String r = elmRequest("015C", 800);
  int d[1];
  if (parseMode01(r, "5C", d, 1) == 1) return d[0] - 40.0;
  return -999;
}

int readRunTime_OBD() {
  if (!pidSupported[0x1F]) return -1;
  String r = elmRequest("011F", 800);
  int d[2];
  if (parseMode01(r, "1F", d, 2) == 2) return (d[0] * 256) + d[1];
  return -1;
}

float readPedalPosition_OBD() {
  if (!pidSupported[0x5A]) return -1;
  String r = elmRequest("015A", 800);
  int d[1];
  if (parseMode01(r, "5A", d, 1) == 1) return (100.0 * d[0]) / 255.0;
  return -1;
}

// ── MIL / DTC (OBD-II Mode 01 PID 01) ──
void readMILStatus_OBD() {
  String r = elmRequest("0101", 800);
  int d[4];
  if (parseMode01(r, "01", d, 4) >= 1) {
    g_milOn = (d[0] & 0x80) != 0;
    g_dtcCount = d[0] & 0x7F;
  }
}

// DTC type prefix
char dtcTypeChar(int firstByte) {
  switch ((firstByte >> 6) & 0x03) {
    case 0: return 'P';
    case 1: return 'C';
    case 2: return 'B';
    case 3: return 'U';
  }
  return 'P';
}

String parseDTCResponse(const String& resp) {
  String result = "";
  String cleaned = resp;
  cleaned.replace("\r", " "); cleaned.replace("\n", " ");
  cleaned.replace(">", ""); cleaned.replace(":", " ");
  cleaned.trim(); cleaned.toUpperCase();
  
  int startIdx = -1;
  if (cleaned.indexOf("43") >= 0) startIdx = cleaned.indexOf("43");
  else if (cleaned.indexOf("47") >= 0) startIdx = cleaned.indexOf("47");
  if (startIdx < 0) return result;
  
  String data = cleaned.substring(startIdx);
  String tokens[40]; int tokCount = 0; int pos = 0;
  data.trim();
  while (pos < (int)data.length() && tokCount < 40) {
    while (pos < (int)data.length() && data[pos] == ' ') pos++;
    int start = pos;
    while (pos < (int)data.length() && data[pos] != ' ') pos++;
    if (pos > start) tokens[tokCount++] = data.substring(start, pos);
  }
  
  for (int i = 1; i + 1 < tokCount; i += 2) {
    int b1 = (int)strtol(tokens[i].c_str(), NULL, 16);
    int b2 = (int)strtol(tokens[i+1].c_str(), NULL, 16);
    if (b1 == 0 && b2 == 0) continue;
    char prefix = dtcTypeChar(b1);
    char dtcBuf[8];
    snprintf(dtcBuf, sizeof(dtcBuf), "%c%d%X%X%X", prefix, (b1>>4)&0x03, b1&0x0F, (b2>>4)&0x0F, b2&0x0F);
    if (result.length() > 0) result += ",";
    result += dtcBuf;
  }
  return result;
}

void readConfirmedDTCs_OBD() {
  String r = elmRequest("03", 3000);
  if (isNoData(r)) { g_dtcCodes = ""; return; }
  g_dtcCodes = parseDTCResponse(r);
}

// ═══════════════════════════════════════════════════
// FUEL ESTIMATION ENGINE (adaptée poids lourds)
// ═══════════════════════════════════════════════════

float computeFuelRateLh() {
  // Priorité 1: Lecture directe J1939 ou OBD PID 5E
  if (g_fuelRateLh > 0) return g_fuelRateLh;
  
  // Priorité 2: MAF (plus fréquent sur VUL)
  if (g_mafGps > 0) {
    float fuelGPerS = g_mafGps / AFR;
    return (fuelGPerS / DENSITY) * 3.6;
  }
  
  // Priorité 3: Estimation par charge moteur + RPM
  // Valeurs adaptées aux moteurs Diesel poids lourds (6-13L de cylindrée)
  if (g_engineLoadPct > 0 && g_rpm > 0) {
    float maxRate = 45.0;  // Poids lourd diesel: ~45 L/h en pleine charge
    float rate = maxRate * (g_engineLoadPct / 100.0) * ((float)g_rpm / 2200.0);
    return constrain(rate, 0.5, maxRate);
  }
  
  // Priorité 4: Idle diesel poids lourd
  if (g_rpm > 0) return 2.5;  // ~2.5 L/h au ralenti pour un PL
  return 0;
}

void updateFuelEstimation(float dtSec) {
  float fuelRate = computeFuelRateLh();
  
  if (g_speedKmh > 3 && fuelRate > 0) {
    g_consoLPer100 = (fuelRate / g_speedKmh) * 100.0;
    g_consoLPer100 = constrain(g_consoLPer100, 0, 99);
  } else if (g_rpm > 0 && g_consoLPer100 <= 0) {
    g_consoLPer100 = fuelRate;
  }
  
  if (fuelRate > 0 && dtSec > 0 && dtSec < 10) {
    g_fuelConsumedL += (fuelRate * dtSec) / 3600.0;
  }
  
  if (!g_fuelPidSupported) {
    g_estimatedFuelPct = ((TANK_CAPACITY_L * 0.50) - g_fuelConsumedL) / TANK_CAPACITY_L * 100.0;
    g_estimatedFuelPct = constrain(g_estimatedFuelPct, 0, 100);
    g_fuelLevelPct = (int)round(g_estimatedFuelPct);
  }
}

// ═══════════════════════════════════════════════════
// MAIN POLL CYCLE — Adaptatif selon le protocole
// ═══════════════════════════════════════════════════

void pollOBD() {
  unsigned long now = millis();
  float dtSec = (g_lastTickMs > 0) ? (now - g_lastTickMs) / 1000.0 : 0.5;
  g_lastTickMs = now;
  g_pollCycle++;
  
  if (g_protocol == PROTO_J1939) {
    // ═══════════════════════════════════════
    // MODE J1939 — Lecture par PGN
    // ═══════════════════════════════════════
    
    // ── RAPIDE (chaque cycle) — RPM + Vitesse ──
    j1939_ReadEngineController1();
    j1939_ReadVehicleSpeed();
    
    // ── MOYEN (tous les 3 cycles) ──
    if (g_pollCycle % 3 == 0) {
      j1939_ReadEngineTemp();
      j1939_ReadEngineController2();
      j1939_ReadFuelEconomy();
      j1939_ReadFluidLevels();
    }
    
    // ── LENT (tous les 10 cycles) ──
    if (g_pollCycle % 10 == 0) {
      j1939_ReadElectricalPower();
      j1939_ReadFuelLevel();
      j1939_ReadInletExhaust();
      j1939_ReadTransmission();
      j1939_ReadAdBlueLevel();
    }
    
    // ── RARE (tous les 30 cycles) ──
    if (g_pollCycle % 30 == 0) {
      j1939_ReadAmbientConditions();
      j1939_ReadEngineHours();
      j1939_ReadOdometer();
      j1939_ReadTotalFuel();
      j1939_ReadRetarder();
      j1939_ReadDM1();
    }
    
  } else {
    // ═══════════════════════════════════════
    // MODE OBD-II — Lecture par PID (fallback)
    // ═══════════════════════════════════════
    
    // ── RAPIDE ──
    int rpmVal = readRPM_OBD();
    if (rpmVal >= 0) g_rpm = rpmVal;
    float spdVal = readSpeed_OBD();
    if (spdVal >= 0) g_speedKmh = spdVal;
    
    // ── MOYEN ──
    if (g_pollCycle % 3 == 0) {
      float t = readEngineTemp_OBD();
      if (t > -999) g_engineTempC = t;
      float load = readEngineLoad_OBD();
      if (load >= 0) g_engineLoadPct = load;
      float maf = readMAF_OBD();
      if (maf >= 0) g_mafGps = maf;
      float fr = readFuelRate_OBD();
      if (fr >= 0) g_fuelRateLh = fr;
      float tps = readTPS_OBD();
      if (tps >= 0) g_tpsPct = tps;
    }
    
    // ── LENT ──
    if (g_pollCycle % 10 == 0) {
      if (g_fuelPidSupported) {
        int fl = readFuelLevel_OBD();
        if (fl >= 0) g_fuelLevelPct = fl;
      }
      float v = readBatteryVoltage_OBD();
      if (v >= 0) g_batteryVoltage = v;
      float iat = readIAT_OBD();
      if (iat > -999) g_iatC = iat;
      float mp = readMAP_OBD();
      if (mp >= 0) g_mapKpa = mp;
      float pedal = readPedalPosition_OBD();
      if (pedal >= 0) g_pedalPct = pedal;
    }
    
    // ── RARE ──
    if (g_pollCycle % 30 == 0) {
      float at = readAmbientTemp_OBD();
      if (at > -999) g_ambientTempC = at;
      float ot = readOilTemp_OBD();
      if (ot > -999) g_oilTempC = ot;
      int rt = readRunTime_OBD();
      if (rt >= 0) g_engineHours = rt / 3600.0;
      readMILStatus_OBD();
      if (g_milOn || g_dtcCount > 0) {
        readConfirmedDTCs_OBD();
      }
    }
  }
  
  // ── Distance + Carburant ──
  float dtH = dtSec / 3600.0;
  g_distanceKm += max(0.0f, g_speedKmh) * dtH;
  updateFuelEstimation(dtSec);
}

// ═══════════════════════════════════════════════════
// SUPABASE UPLOAD — Payload complet poids lourd
// ═══════════════════════════════════════════════════

void uploadToSupabase() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[UPLOAD] Wi-Fi non connecté");
    return;
  }
  
  static bool firstRun = true;
  if (firstRun) {
    firstRun = false;
    Serial.printf("[NET] IP: %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("[NET] Free heap: %d bytes\n", ESP.getFreeHeap());
  }
  
  // ── Build JSON payload — ALL data for FleetGuard AI ──
  char payload[1024];
  {
    StaticJsonDocument<900> doc;
    doc["camion"]             = CAMION_ID;
    doc["rpm"]                = g_rpm;
    doc["temperature"]        = (int)round(g_engineTempC);
    doc["vitesse"]            = (int)round(g_speedKmh);
    doc["carburant"]          = max(0, g_fuelLevelPct);
    doc["conso_l_100"]        = g_consoLPer100;
    doc["distance_km"]        = g_distanceKm;
    doc["fuel_consumed_total_l"] = g_fuelConsumedL;
    
    // Pression huile : RÉELLE en J1939, estimée en OBD-II
    if (g_oilPressureBar >= 0) {
      doc["pression_huile_bar"] = g_oilPressureBar;
    } else {
      doc["pression_huile_bar"] = (float)constrain(1.5 + (g_rpm / 6000.0), 0.0, 6.0);
    }
    
    // ── Moteur ──
    if (g_engineLoadPct >= 0)    doc["engine_load_pct"]    = g_engineLoadPct;
    if (g_batteryVoltage >= 0)   doc["battery_voltage"]    = g_batteryVoltage;
    float fRate = computeFuelRateLh();
    if (fRate > 0) doc["fuel_rate_lh"] = fRate;
    
    // ── Températures ──
    if (g_oilTempC > -900)       doc["oil_temp_c"]         = g_oilTempC;
    if (g_ambientTempC > -900)   doc["ambient_temp_c"]     = g_ambientTempC;
    if (g_iatC > -900)           doc["iat_c"]              = g_iatC;
    if (g_fuelTempC > -900)      doc["fuel_temp_c"]        = g_fuelTempC;
    
    // ── Pressions ──
    if (g_mapKpa >= 0)           doc["map_kpa"]            = g_mapKpa;
    if (g_baroKpa >= 0)          doc["baro_kpa"]           = g_baroKpa;
    if (g_fuelPressureKpa >= 0)  doc["fuel_pressure_kpa"]  = g_fuelPressureKpa;
    
    // ── Conduite ──
    if (g_pedalPct >= 0)         doc["pedal_pct"]          = g_pedalPct;
    if (g_engineHours >= 0)      doc["run_time_sec"]       = (int)(g_engineHours * 3600);
    
    // ── Spécifique Poids Lourd ──
    if (g_turboPressureKpa >= 0) doc["turbo_pressure_kpa"] = g_turboPressureKpa;
    if (g_exhaustTempC > -900)   doc["exhaust_temp_c"]     = g_exhaustTempC;
    if (g_adBlueLevelPct >= 0)   doc["adblue_level_pct"]   = g_adBlueLevelPct;
    if (g_gearCurrent > -127)    doc["gear_current"]       = g_gearCurrent;
    if (g_torquePct > -200)      doc["torque_pct"]         = g_torquePct;
    if (g_odometerKm >= 0)       doc["odometer_km"]        = g_odometerKm;
    if (g_retarderPct >= 0)      doc["retarder_pct"]       = g_retarderPct;
    if (g_coolantLevelPct >= 0)  doc["coolant_level_pct"]  = g_coolantLevelPct;
    if (g_fuelTotalL >= 0)       doc["fuel_total_l"]       = g_fuelTotalL;
    
    // ── Diagnostics ──
    doc["mil_on"]    = g_milOn;
    doc["dtc_count"] = g_dtcCount;
    if (g_dtcCodes.length() > 0) doc["dtc_codes"] = g_dtcCodes;
    
    // ── Status ──
    doc["status_ok"] = !g_milOn && (g_engineTempC < 105);
    doc["protocol"]  = (g_protocol == PROTO_J1939) ? "J1939" : "OBD-II";
    
    serializeJson(doc, payload, sizeof(payload));
  }
  
  int payloadLen = strlen(payload);
  Serial.printf("[UPLOAD] Payload (%d bytes) | Heap: %d\n", payloadLen, ESP.getFreeHeap());
  
  // ── Temporarily disconnect BT for SSL ──
  SerialBT.disconnect();
  delay(100);
  
  bool usedFullEnd = false;
  if (ESP.getFreeHeap() < 45000) {
    SerialBT.end();
    delay(200);
    usedFullEnd = true;
  }
  
  // ── HTTPS POST ──
  {
    WiFiClientSecure client;
    client.setInsecure();
    client.setTimeout(15);
    
    const char* supa_host = "obwbtsgibyvbmslzrbwu.supabase.co";
    
    if (client.connect(supa_host, 443)) {
      client.printf("POST /rest/v1/%s HTTP/1.1\r\n", TABLE_NAME);
      client.printf("Host: %s\r\n", supa_host);
      client.print("Content-Type: application/json\r\n");
      client.printf("apikey: %s\r\n", SUPABASE_KEY);
      client.printf("Authorization: Bearer %s\r\n", SUPABASE_KEY);
      client.print("Prefer: return=minimal\r\n");
      client.printf("Content-Length: %d\r\n", payloadLen);
      client.print("Connection: close\r\n\r\n");
      client.write((uint8_t*)payload, payloadLen);
      
      unsigned long t0 = millis();
      while (!client.available() && (millis() - t0) < 10000) delay(10);
      
      if (client.available()) {
        String statusLine = client.readStringUntil('\n');
        statusLine.trim();
        Serial.println("[UPLOAD] " + statusLine);
        
        // Si erreur, afficher le body
        if (statusLine.indexOf("201") < 0) {
          while (client.available()) {
            String line = client.readStringUntil('\n');
            line.trim();
            if (line.startsWith("{")) {
              Serial.println("[UPLOAD] Erreur: " + line);
              break;
            }
          }
        }
      }
      client.stop();
    } else {
      Serial.println("[UPLOAD] ✗ SSL FAILED");
      
      if (!usedFullEnd) {
        SerialBT.end();
        delay(200);
        usedFullEnd = true;
        
        WiFiClientSecure client2;
        client2.setInsecure();
        client2.setTimeout(15);
        if (client2.connect(supa_host, 443)) {
          client2.printf("POST /rest/v1/%s HTTP/1.1\r\n", TABLE_NAME);
          client2.printf("Host: %s\r\n", supa_host);
          client2.print("Content-Type: application/json\r\n");
          client2.printf("apikey: %s\r\n", SUPABASE_KEY);
          client2.printf("Authorization: Bearer %s\r\n", SUPABASE_KEY);
          client2.print("Prefer: return=minimal\r\n");
          client2.printf("Content-Length: %d\r\n", payloadLen);
          client2.print("Connection: close\r\n\r\n");
          client2.write((uint8_t*)payload, payloadLen);
          unsigned long t1 = millis();
          while (!client2.available() && (millis() - t1) < 10000) delay(10);
          if (client2.available()) {
            String line = client2.readStringUntil('\n');
            Serial.println("[UPLOAD] " + line);
          }
        }
        client2.stop();
      }
    }
  }
  
  // ── Reconnect BT ──
  if (usedFullEnd) {
    Serial.println("[BT] Reconnexion complète...");
    SerialBT.setPin(PIN_CODE, strlen(PIN_CODE));
    SerialBT.begin("FleetGuard_PL", true);
    delay(300);
    elmConnected = SerialBT.connect(const_cast<uint8_t*>(ELM_MAC));
    if (elmConnected) {
      delay(300);
      while (SerialBT.available()) SerialBT.read();
      elmRequest("ATZ", 3000);
      delay(800);
      while (SerialBT.available()) SerialBT.read();
      elmRequest("ATE0", 800);
      elmRequest("ATL0", 800);
      elmRequest("ATH0", 800);
      elmRequest("ATS1", 800);
      elmRequest("ATAT1", 800);
      elmRequest("ATST64", 800);
      
      if (g_protocol == PROTO_J1939) {
        elmRequest("ATSP A", 1500);
        elmRequest("ATJTM5", 800);
      } else {
        elmRequest("ATSP0", 1500);
      }
      
      Serial.println("[BT] ✓ Reconnecté !");
    } else {
      Serial.println("[BT] ✗ Échec reconnexion");
    }
  } else {
    elmConnected = SerialBT.connect(const_cast<uint8_t*>(ELM_MAC));
    if (elmConnected) {
      delay(200);
      while (SerialBT.available()) SerialBT.read();
      elmRequest("ATE0", 800);
      elmRequest("ATS1", 800);
      
      if (g_protocol == PROTO_J1939) {
        elmRequest("ATSP A", 800);
      }
    } else {
      // Full restart
      SerialBT.end();
      delay(200);
      SerialBT.setPin(PIN_CODE, strlen(PIN_CODE));
      SerialBT.begin("FleetGuard_PL", true);
      delay(300);
      elmConnected = SerialBT.connect(const_cast<uint8_t*>(ELM_MAC));
      if (elmConnected) {
        delay(300);
        while (SerialBT.available()) SerialBT.read();
        elmRequest("ATZ", 3000);
        delay(800);
        while (SerialBT.available()) SerialBT.read();
        elmRequest("ATE0", 800);
        elmRequest("ATH0", 800);
        elmRequest("ATS1", 800);
        
        if (g_protocol == PROTO_J1939) {
          elmRequest("ATSP A", 1500);
          elmRequest("ATJTM5", 800);
        } else {
          elmRequest("ATSP0", 1500);
        }
      }
    }
  }
}

// ═══════════════════════════════════════════════════
// DASHBOARD SÉRIE — Adapté poids lourd
// ═══════════════════════════════════════════════════

String gearStr(int gear) {
  if (gear == -1) return "R";
  if (gear == 0)  return "N";
  if (gear > 0)   return String(gear);
  return "?";
}

void printDashboard() {
  Serial.println("╔═══════════════════════════════════════════════════╗");
  Serial.println("║      FleetGuard — Tableau de Bord Poids Lourd    ║");
  Serial.printf( "║      Protocole: %-10s   Cycle: %5d         ║\n",
                 (g_protocol == PROTO_J1939) ? "J1939" : "OBD-II", g_pollCycle);
  Serial.println("╠═══════════════════════════════════════════════════╣");
  Serial.printf( "║ RPM:         %5d tr/min                        ║\n", g_rpm);
  Serial.printf( "║ Vitesse:     %5.0f km/h                          ║\n", g_speedKmh);
  Serial.printf( "║ Temp Moteur: %5.0f °C                            ║\n", g_engineTempC);
  Serial.printf( "║ Charge:      %5.1f %%                             ║\n", max(0.0f, g_engineLoadPct));
  if (g_torquePct > -200)
    Serial.printf("║ Couple:      %5.1f %%                             ║\n", g_torquePct);
  if (g_gearCurrent > -127)
    Serial.printf("║ Rapport:     %5s                                ║\n", gearStr(g_gearCurrent).c_str());
  
  Serial.println("╠── Carburant ─────────────────────────────────────╣");
  Serial.printf( "║ Niveau:      %5d %% %s              ║\n", 
                 max(0, g_fuelLevelPct), g_fuelPidSupported ? "(capteur)" : "(estimé) ");
  Serial.printf( "║ Débit:       %5.1f L/h                           ║\n", max(0.0f, computeFuelRateLh()));
  Serial.printf( "║ Conso:       %5.1f L/100km                       ║\n", g_consoLPer100);
  Serial.printf( "║ Consommé:    %5.1f L (session)                   ║\n", g_fuelConsumedL);
  if (g_adBlueLevelPct >= 0)
    Serial.printf("║ AdBlue:      %5d %%                              ║\n", g_adBlueLevelPct);
  
  Serial.println("╠── Système ──────────────────────────────────────╣");
  if (g_oilPressureBar >= 0)
    Serial.printf("║ Pression H:  %5.1f bar                           ║\n", g_oilPressureBar);
  if (g_oilTempC > -900)
    Serial.printf("║ Temp Huile:  %5.0f °C                            ║\n", g_oilTempC);
  if (g_turboPressureKpa >= 0)
    Serial.printf("║ Turbo:       %5.0f kPa                           ║\n", g_turboPressureKpa);
  if (g_exhaustTempC > -900)
    Serial.printf("║ Échappement: %5.0f °C                            ║\n", g_exhaustTempC);
  if (g_batteryVoltage > 0)
    Serial.printf("║ Batterie:    %5.1f V                             ║\n", g_batteryVoltage);
  if (g_ambientTempC > -900)
    Serial.printf("║ Temp ext:    %5.0f °C                            ║\n", g_ambientTempC);
  
  Serial.printf( "║ MIL (Voyant): %s   DTCs: %d                    ║\n",
                 g_milOn ? "ALLUMÉ ⚠" : "éteint  ", g_dtcCount);
  Serial.printf( "║ Distance:    %7.1f km (session)                 ║\n", g_distanceKm);
  if (g_odometerKm >= 0)
    Serial.printf("║ Odomètre:   %9.0f km (total)                  ║\n", g_odometerKm);
  if (g_engineHours >= 0)
    Serial.printf("║ Heures:      %7.0f h (total)                    ║\n", g_engineHours);
  
  Serial.printf( "║ Wi-Fi:       %s                           ║\n",
                 WiFi.status() == WL_CONNECTED ? "OK   " : "DÉCO ");
  Serial.println("╚═══════════════════════════════════════════════════╝");
}

// ═══════════════════════════════════════════════════
// SETUP
// ═══════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  Serial.println("\n══════════════════════════════════════════════");
  Serial.println("  FleetGuard AI — Firmware Poids Lourd v2.0");
  Serial.println("  Protocoles: J1939 CAN + OBD-II (auto-detect)");
  Serial.println("══════════════════════════════════════════════\n");
  
  pinMode(2, OUTPUT);
  
  // ── Wi-Fi ──
  Serial.printf("[WIFI] Connexion à %s...\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 20) {
    delay(500); Serial.print("."); wifiAttempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WIFI] ✓ Connecté ! IP: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("\n[WIFI] ✗ Échec — nouvelle tentative plus tard");
  }
  
  // ── Bluetooth → ELM327 ──
  Serial.println("[BT] Initialisation Bluetooth...");
  SerialBT.setPin(PIN_CODE, strlen(PIN_CODE));
  SerialBT.begin("FleetGuard_PL", true);
  
  Serial.println("[BT] Connexion à l'ELM327...");
  elmConnected = SerialBT.connect(const_cast<uint8_t*>(ELM_MAC));
  
  if (!elmConnected) {
    Serial.println("[BT] ✗ Échec de connexion à l'ELM327 !");
    Serial.println("[BT] Vérifiez que l'adaptateur est branché sur la prise OBD.");
    for (int i = 0; i < 20; i++) {
      digitalWrite(2, !digitalRead(2));
      delay(200);
    }
    return;
  }
  
  Serial.println("[BT] ✓ Connecté à l'ELM327 !");
  digitalWrite(2, HIGH);
  
  // ── Init + Auto-détection du protocole ──
  if (!initELM327()) {
    Serial.println("[ELM] ÉCHEC d'initialisation !");
    elmConnected = false;
    return;
  }
  
  // ── Détection des PIDs (si OBD-II) ──
  detectSupportedPids();
  
  g_lastTickMs = millis();
  Serial.println();
  Serial.println("╔═══════════════════════════════════════════════════╗");
  Serial.printf( "║  ✅ SYSTÈME PRÊT — Protocole: %-10s          ║\n",
                 (g_protocol == PROTO_J1939) ? "J1939" : "OBD-II");
  Serial.println("║  Démarrage de l'acquisition de données...        ║");
  Serial.println("╚═══════════════════════════════════════════════════╝\n");
}

// ═══════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════

void loop() {
  if (!elmConnected) {
    Serial.println("[BT] Tentative de reconnexion...");
    elmConnected = SerialBT.connect(const_cast<uint8_t*>(ELM_MAC));
    if (elmConnected) {
      Serial.println("[BT] ✓ Reconnecté !");
      initELM327();
      detectSupportedPids();
      digitalWrite(2, HIGH);
    } else {
      digitalWrite(2, LOW);
      delay(10000);
      return;
    }
  }
  
  // Wi-Fi reconnect
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.reconnect();
  }
  
  // Poll
  unsigned long now = millis();
  pollOBD();
  
  // Upload
  if ((now - g_lastUploadMs) >= UPLOAD_INTERVAL_MS) {
    g_lastUploadMs = now;
    uploadToSupabase();
  }
  
  // Dashboard local
  if ((now - g_lastDashboardMs) >= 3000) {
    g_lastDashboardMs = now;
    printDashboard();
  }
  
  // LED heartbeat
  digitalWrite(2, (g_pollCycle % 2 == 0) ? HIGH : LOW);
  delay(10);
}
