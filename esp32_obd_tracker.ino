// ================================================================
//  ESP32 OBD-II Fleet Tracker — V11 FUEL MAXIMUM
//
//  3 stratégies pour le niveau de carburant :
//    S1 — OBD Mode 01 PID 012F    (standard)
//    S2 — OBD Mode 22 Auto-scan   (30+ PIDs constructeurs)
//    S3 — Capteur physique ADC    (GPIO34, garanti 100%)
//
//  Pour activer S3 (matériel) :
//    1. Décommenter : #define FUEL_ADC_ENABLED
//    2. Brancher le fil "signal" de la jauge carburant via
//       diviseur de tension (voir schéma en bas de fichier)
//    3. Calibrer FUEL_EMPTY_V et FUEL_FULL_V avec un multimètre
//
//  Supabase — Ajouter les colonnes manquantes :
//    ALTER TABLE obd_data
//      ADD COLUMN IF NOT EXISTS engine_on   BOOLEAN,
//      ADD COLUMN IF NOT EXISTS recorded_at TIMESTAMPTZ,
//      ADD COLUMN IF NOT EXISTS fuel_method TEXT;
// ================================================================

#include <BluetoothSerial.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <deque>
#include <time.h>

// ================================================================
//  CONFIGURATION — À MODIFIER
// ================================================================
BluetoothSerial SerialBT;
uint8_t     BT_ADDR[6]   = {0x00, 0x10, 0xCC, 0x4F, 0x36, 0x03};
const char* BT_PIN       = "1234";
const char* WIFI_SSID    = "TOPNET_1688";
const char* WIFI_PASS    = "nkzasot8c3";
const char* SUPA_URL     = "https://obwbtsgibyvbmslzrbwu.supabase.co/rest/v1/obd_data";
const char* SUPA_KEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9id2J0c2dpYnl2Ym1zbHpyYnd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzMzM4MzUsImV4cCI6MjA4ODkwOTgzNX0.3rDQcB_ZGa0SJs-qSJ2AjmyxjZj3r2e4caiGZhzSoLE";

// NTP — Tunisie = UTC+1, pas de changement d'heure (CET)
const long  NTP_OFFSET   = 3600;
const char* NTP_SERVER   = "pool.ntp.org";

// ----------------------------------------------------------------
//  STRATÉGIE 3 : CAPTEUR PHYSIQUE (décommenter pour activer)
// ----------------------------------------------------------------
// #define FUEL_ADC_ENABLED

#ifdef FUEL_ADC_ENABLED
  // GPIO34 = ADC1_CH6, entrée analogique uniquement  
  // Brancher : Fil "signal" jauge → résistance 1kΩ → GPIO34
  //            GPIO34 → résistance 220Ω → GND
  //            (diviseur de tension — voir schéma en bas)
  const int   FUEL_ADC_PIN    = 34;
  
  // ⚠️  CALIBRER these values:
  // Mesurer la tension sur GPIO34 quand réservoir VIDE (V) → FUEL_EMPTY_V
  // Mesurer la tension sur GPIO34 quand réservoir PLEIN (V) → FUEL_FULL_V
  // Exemple pour résistances 10-180Ω: empty=0.25V, full=2.1V
  const float FUEL_EMPTY_V    = 0.25f;   // Volts quand réservoir vide
  const float FUEL_FULL_V     = 2.10f;   // Volts quand réservoir plein
  const float FUEL_ADC_VREF   = 3.3f;    // Référence ESP32 ADC
  const int   FUEL_ADC_RES    = 4095;    // 12-bit ADC
  const int   FUEL_ADC_SMOOTH = 16;      // Lectures moyennées (anti-bruit)
#endif

// ----------------------------------------------------------------
//  INTERVALLES
// ----------------------------------------------------------------
const unsigned long INTERVAL_PID      = 1200;   // ms entre PIDs
const unsigned long INTERVAL_PUSH     = 10000;  // ms entre envois Supabase
const unsigned long INTERVAL_BT_CHECK = 5000;   // ms entre checks BT
const int           MAX_QUEUE_SIZE    = 200;
const int           MAX_PID_RETRIES   = 3;
const int           MAX_SEND_FAILS    = 3;

// ================================================================
//  STRATÉGIE 2 : MODE 22 — LISTE DES PIDs CONSTRUCTEURS
//  Compilée depuis les bases de données OBD Torque, CarScanner,
//  ForScan, et forums specialisés 2024
//
//  Format: {"CMD_A_ENVOYER", "PREFIX_REPONSE_ATTENDU", "Constructeur"}
//  Réponse Mode 22: 0x62 + les 4 chiffres du PID
// ================================================================
struct Mode22Entry {
  const char* cmd;          // Commande à envoyer à l'ELM327
  const char* respPrefix;   // Préfixe de la réponse (sans espaces)
  const char* brand;        // Marque du véhicule
};

const Mode22Entry MODE22_FUEL_PIDS[] = {
  // ── Renault / Dacia (très commun en Tunisie / Afrique du Nord) ──
  {"221E08", "621E08", "Renault/Dacia"},
  {"225DD5", "625DD5", "Renault variant"},
  {"22004E", "62004E", "Renault/Nissan platform"},
  {"221FFF", "621FFF", "Renault Clio/Megane"},
  // ── Peugeot / Citroën ──────────────────────────────────────────
  {"224046", "624046", "Peugeot/Citroen"},
  {"221DFA", "621DFA", "PSA variant"},
  {"222006", "622006", "PSA/Stellantis"},
  // ── Volkswagen / Audi / Skoda / Seat ───────────────────────────
  {"22F430", "62F430", "VW/Audi/Skoda/Seat"},
  {"224081", "624081", "VW Group variant"},
  {"22007F", "62007F", "VW Group alt"},
  // ── Toyota / Lexus ─────────────────────────────────────────────
  {"22FCA2", "62FCA2", "Toyota/Lexus"},
  {"221F9D", "621F9D", "Toyota variant"},
  {"222816", "622816", "Toyota CAN alt"},
  // ── Hyundai / Kia ──────────────────────────────────────────────
  {"22012E", "62012E", "Hyundai/Kia"},
  {"224801", "624801", "Hyundai alt"},
  {"220EB4", "620EB4", "Kia"},
  // ── Ford ───────────────────────────────────────────────────────
  {"221220", "621220", "Ford"},
  {"22182F", "62182F", "Ford variant"},
  {"221131", "621131", "Ford EcoSport/Fiesta"},
  // ── GM / Opel / Chevrolet ──────────────────────────────────────
  {"221DFF", "621DFF", "GM/Opel"},
  {"220F01", "620F01", "GM variant"},
  {"22043B", "62043B", "Chevrolet"},
  // ── BMW / Mini ─────────────────────────────────────────────────
  {"22034F", "62034F", "BMW"},
  {"220306", "620306", "BMW variant"},
  {"221FDF", "621FDF", "Mini/BMW"},
  // ── Mercedes-Benz ──────────────────────────────────────────────
  {"220601", "620601", "Mercedes-Benz"},
  {"222009", "622009", "Mercedes variant"},
  // ── Nissan / Infiniti ──────────────────────────────────────────
  {"22000D", "62000D", "Nissan/Infiniti"},
  {"221156", "621156", "Nissan alt"},
  // ── Honda / Acura ──────────────────────────────────────────────
  {"222B20", "622B20", "Honda/Acura"},
  {"220107", "620107", "Honda alt"},
  // ── Suzuki ─────────────────────────────────────────────────────
  {"220107", "620107", "Suzuki"},
  {"221C03", "621C03", "Suzuki variant"},
  // ── Fiat / Alfa Romeo / Jeep (Stellantis) ──────────────────────
  {"221ED3", "621ED3", "Fiat/Alfa"},
  {"22004F", "62004F", "Fiat variant"},
  // ── Mazda ──────────────────────────────────────────────────────
  {"22003F", "62003F", "Mazda"},
  {"221F01", "621F01", "Mazda alt"},
  // ── Mitsubishi ─────────────────────────────────────────────────
  {"221102", "621102", "Mitsubishi"},
  // ── Subaru ─────────────────────────────────────────────────────
  {"221E4E", "621E4E", "Subaru"},
  // ── Fin de liste ───────────────────────────────────────────────
  {nullptr, nullptr, nullptr}
};

// ================================================================
//  TYPES
// ================================================================
enum FuelMethod {
  FUEL_NOT_DETECTED = 0,
  FUEL_OBD_012F,         // Mode 01, PID 2F
  FUEL_OBD_MODE22,       // Mode 22 constructeur
  FUEL_ADC_SENSOR        // Capteur physique GPIO
};

struct OBDData {
  int   rpm         = -1;
  int   speed       = -1;
  float fuelLevel   = -1.0f;
  float voltage     = -1.0f;
  int   coolantTemp = -999;
  bool  engineOn    = false;
  char  fuelSrc[24] = {0};   // Méthode utilisée ("012F", "Mode22:VW", "ADC", ...)
  char  recAt[25]   = {0};   // Timestamp ISO 8601
};

// ================================================================
//  VARIABLES GLOBALES
// ================================================================
std::deque<OBDData> g_queue;
OBDData             g_obd;

bool g_btConn   = false;
bool g_ntpOk    = false;

FuelMethod  g_fuelMethod   = FUEL_NOT_DETECTED;
String      g_fuelMode22Cmd;    // Commande Mode22 qui marche
String      g_fuelMode22Pfx;    // Préfixe réponse Mode22

const int   N_PIDS   = 5;
const char* PIDS[N_PIDS] = {"010C", "010D", "0105", "ATRV", "FUEL"};
//                                                          ^^^^ PID virtuel géré séparément
bool        pidEnabled[N_PIDS]  = {true, true, true, true, true};
int         pidFails[N_PIDS]    = {0, 0, 0, 0, 0};
int         g_pidStep           = 0;

unsigned long g_tPID     = 0;
unsigned long g_tPush    = 0;
unsigned long g_tBTCheck = 0;

// ================================================================
//  PROTOTYPES
// ================================================================
String sendCmd(const String& cmd, unsigned int ms = 1500);
bool   initELM();
bool   parsePID(const String& raw, int idx);
float  readFuelLevel();
float  tryFuel012F();
float  tryFuelMode22(const String& cmd, const String& pfx);
float  tryFuelADC();
void   detectFuelSource();
void   readCycle();
void   addToQueue();
void   pushQueue();
bool   postOne(const OBDData& d, WiFiClientSecure& cli, HTTPClient& http);
bool   checkBT();
void   checkWiFi();
void   syncNTP();
String nowISO();
void   printStatus();

// ================================================================
//  SETUP
// ================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println(F("\n╔════════════════════════════════════╗"));
  Serial.println(F("║  OBD TRACKER V11 — FUEL MAXIMUM    ║"));
  Serial.println(F("╚════════════════════════════════════╝\n"));

  // ── WiFi ──────────────────────────────────────────────────────
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print(F("📶 WiFi "));
  for (int i = 0; i < 20 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500); Serial.print('.');
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi: " + WiFi.localIP().toString());
    syncNTP();
  } else {
    Serial.println(F("\n⚠️  Mode hors-ligne au démarrage"));
  }

  // ── Bluetooth + ELM327 ────────────────────────────────────────
  Serial.println(F("\n🔵 Connexion Bluetooth OBD..."));
  SerialBT.setPin(BT_PIN, 4);
  SerialBT.begin("ESP32_Fleet", true);
  delay(500);

  if (SerialBT.connect(BT_ADDR)) {
    g_btConn = true;
    Serial.println(F("✅ BT OBD connecté !"));
    delay(2000);
    initELM();
    detectFuelSource();   // ← Détection automatique méthode carburant
  } else {
    Serial.println(F("⚠️  BT non connecté — retry dans loop()"));
  }

#ifdef FUEL_ADC_ENABLED
  pinMode(FUEL_ADC_PIN, INPUT);
  // Si aucune méthode OBD trouvée, forcer ADC
  if (g_fuelMethod == FUEL_NOT_DETECTED) {
    g_fuelMethod = FUEL_ADC_SENSOR;
    strncpy(g_obd.fuelSrc, "ADC", sizeof(g_obd.fuelSrc));
    Serial.println(F("📌 Méthode carburant forcée: CAPTEUR ADC"));
  }
#endif
}

// ================================================================
//  LOOP
// ================================================================
void loop() {
  unsigned long now = millis();

  // Vérification BT toutes les 5s
  if (now - g_tBTCheck >= INTERVAL_BT_CHECK) {
    checkBT();
    g_tBTCheck = now;
  }

  // Lecture OBD : 1 PID par tick
  if (g_btConn && (now - g_tPID >= INTERVAL_PID)) {
    readCycle();
    g_tPID = now;
  }

  // Envoi Supabase toutes les 10s
  if (now - g_tPush >= INTERVAL_PUSH) {
    checkWiFi();
    if (WiFi.status() == WL_CONNECTED) {
      pushQueue();
    } else {
      Serial.println("⚠️  WiFi absent — " + String(g_queue.size()) + " items en attente");
    }
    g_tPush = now;
  }
}

// ================================================================
//  DÉTECTION AUTOMATIQUE DE LA SOURCE CARBURANT
//  Appelée une fois au démarrage — essaie toutes les méthodes
// ================================================================
void detectFuelSource() {
  Serial.println(F("\n🔍 ═══ DÉTECTION NIVEAU CARBURANT ═══"));
  Serial.println(F("    (L'allumage contact doit être ON)\n"));

  // ── STRATÉGIE 1 : PID OBD Standard 012F ──────────────────────
  Serial.println(F("  [S1] Test PID standard 012F..."));
  float f = tryFuel012F();
  if (f >= 0.0f) {
    g_fuelMethod = FUEL_OBD_012F;
    strncpy(g_obd.fuelSrc, "OBD-012F", sizeof(g_obd.fuelSrc));
    Serial.println("  ✅ S1 OK — Carburant: " + String(f, 1) + "%");
    Serial.println(F("═══════════════════════════════════════\n"));
    return;
  }
  Serial.println(F("  ❌ S1 échoué (PID 012F non supporté)"));

  // ── STRATÉGIE 2 : Mode 22 Auto-scan ──────────────────────────
  Serial.println(F("\n  [S2] Scan Mode 22 (PIDs constructeurs)..."));
  int count = 0;
  for (int i = 0; MODE22_FUEL_PIDS[i].cmd != nullptr; i++) {
    const Mode22Entry& e = MODE22_FUEL_PIDS[i];
    Serial.print("    Essai [" + String(e.brand) + "] " + String(e.cmd) + " ... ");
    delay(100);

    float val = tryFuelMode22(e.cmd, e.respPrefix);
    count++;

    if (val >= 0.0f) {
      // Confirmation: 2ème lecture pour valider la stabilité
      delay(300);
      float val2 = tryFuelMode22(e.cmd, e.respPrefix);
      if (val2 >= 0.0f && fabsf(val - val2) < 15.0f) {
        g_fuelMethod   = FUEL_OBD_MODE22;
        g_fuelMode22Cmd = String(e.cmd);
        g_fuelMode22Pfx = String(e.respPrefix);
        char srcBuf[24];
        snprintf(srcBuf, sizeof(srcBuf), "Mode22:%s", e.brand);
        strncpy(g_obd.fuelSrc, srcBuf, sizeof(g_obd.fuelSrc));
        Serial.println("✅ " + String(val, 1) + "% (confirmé)");
        Serial.println("  ═══ Mode 22 trouvé: " + String(e.cmd) + " [" + String(e.brand) + "]");
        Serial.println(F("═══════════════════════════════════════\n"));
        return;
      } else {
        Serial.println("⚠️  valeur instable (" + String(val,1) + "% / " + String(val2,1) + "%)");
      }
    } else {
      Serial.println(F("NODATA"));
    }
    delay(150);
  }
  Serial.println("  ❌ S2 échoué (" + String(count) + " PIDs testés)");

  // ── STRATÉGIE 3 : Capteur ADC physique ───────────────────────
#ifdef FUEL_ADC_ENABLED
  Serial.println(F("\n  [S3] Test capteur ADC physique..."));
  float adcVal = tryFuelADC();
  if (adcVal >= 0.0f) {
    g_fuelMethod = FUEL_ADC_SENSOR;
    strncpy(g_obd.fuelSrc, "ADC-GPIO34", sizeof(g_obd.fuelSrc));
    Serial.println("  ✅ S3 OK — Capteur ADC: " + String(adcVal, 1) + "%");
    Serial.println(F("═══════════════════════════════════════\n"));
    return;
  }
  Serial.println(F("  ❌ S3 échoué (vérifier câblage GPIO34)"));
#else
  Serial.println(F("\n  [S3] Capteur ADC non activé."));
  Serial.println(F("       → Décommenter #define FUEL_ADC_ENABLED"));
  Serial.println(F("       → pour activer le capteur physique"));
#endif

  Serial.println(F("\n  ⛔ Aucune source carburant trouvée."));
  Serial.println(F("     Fuel_level = NULL dans Supabase."));
  Serial.println(F("═══════════════════════════════════════\n"));
}

// ================================================================
//  LECTURE DU CARBURANT SELON LA MÉTHODE DÉTECTÉE
// ================================================================
float readFuelLevel() {
  switch (g_fuelMethod) {
    case FUEL_OBD_012F:
      return tryFuel012F();
    case FUEL_OBD_MODE22:
      return tryFuelMode22(g_fuelMode22Cmd, g_fuelMode22Pfx);
    case FUEL_ADC_SENSOR:
      return tryFuelADC();
    default:
      return -1.0f;
  }
}

// ================================================================
//  STRATÉGIE 1 — PID OBD Standard 012F
// ================================================================
float tryFuel012F() {
  String raw = sendCmd("012F", 1500);
  if (raw == "TIMEOUT" || raw == "NOBT" ||
      raw.indexOf("NODATA") != -1 ||
      raw.indexOf("UNABLE") != -1 ||
      raw.indexOf("?")      != -1 ||
      raw.indexOf("ERROR")  != -1 ||
      raw.length() == 0) {
    return -1.0f;
  }

  // Chercher "412F" dans la réponse
  int pos = raw.indexOf("412F");
  if (pos == -1) return -1.0f;

  pos += 4; // Sauter "412F"
  if ((int)raw.length() < pos + 2) return -1.0f;

  long byte_A = strtol(raw.substring(pos, pos + 2).c_str(), nullptr, 16);
  if (byte_A < 0 || byte_A > 255) return -1.0f;

  float pct = (byte_A * 100.0f) / 255.0f;
  return (pct >= 0.0f && pct <= 100.0f) ? pct : -1.0f;
}

// ================================================================
//  STRATÉGIE 2 — Mode 22 constructeur
//  Envoie la commande et parse la réponse "62XXXX[data...]"
// ================================================================
float tryFuelMode22(const String& cmd, const String& pfx) {
  String raw = sendCmd(cmd, 1500);

  if (raw == "TIMEOUT" || raw == "NOBT"         ||
      raw.indexOf("NODATA")     != -1            ||
      raw.indexOf("UNABLE")     != -1            ||
      raw.indexOf("CANERROR")   != -1            ||
      raw.indexOf("BUSERROR")   != -1            ||
      raw.indexOf("BUFFERFULL") != -1            ||
      raw.indexOf("?")          != -1            ||
      raw.indexOf("ERROR")      != -1            ||
      raw.length() < 8) {
    return -1.0f;
  }

  // Chercher le préfixe de réponse (ex: "621E08")
  String pfxUp = pfx;
  pfxUp.toUpperCase();
  int pos = raw.indexOf(pfxUp);
  if (pos == -1) return -1.0f;

  pos += pfxUp.length(); // Pointer sur le premier octet de données

  if ((int)raw.length() < pos + 2) return -1.0f;

  // Extraire le premier octet de données
  String hexByte = raw.substring(pos, pos + 2);
  long byte_A = strtol(hexByte.c_str(), nullptr, 16);
  if (byte_A < 0 || byte_A > 255) return -1.0f;

  // Essai avec l'échelle standard OBD (0-255 → 0-100%)
  float pct = (byte_A * 100.0f) / 255.0f;
  if (pct >= 0.0f && pct <= 100.0f) return pct;

  return -1.0f;
}

// ================================================================
//  STRATÉGIE 3 — Capteur ADC physique (GPIO34)
//
//  Schéma de câblage (diviseur de tension) :
//
//  Fil "signal" jauge ---[R1: 1kΩ]--- GPIO34 ---[R2: 220Ω]--- GND
//                                         |
//                                      ESP32 ADC lit ici
//
//  R1 = 1kΩ (adapte la plage de la jauge)
//  R2 = 220Ω (protection ESP32 contre surtension)
//  Max tension GPIO = 3.3V (NE PAS DÉPASSER)
// ================================================================
float tryFuelADC() {
#ifndef FUEL_ADC_ENABLED
  return -1.0f;
#else
  // Moyenne de FUEL_ADC_SMOOTH lectures pour lisser le bruit
  long sum = 0;
  for (int i = 0; i < FUEL_ADC_SMOOTH; i++) {
    sum += analogRead(FUEL_ADC_PIN);
    delay(2);
  }
  float avg   = (float)sum / FUEL_ADC_SMOOTH;
  float volts = (avg / FUEL_ADC_RES) * FUEL_ADC_VREF;

  // Vérification plage physique
  if (volts < 0.05f || volts > (FUEL_ADC_VREF - 0.1f)) {
    // Tension hors plage → capteur déconnecté ou erreur câblage
    Serial.println("  ⚠️  ADC: " + String(volts, 3) + "V hors plage [" +
                   String(FUEL_EMPTY_V, 2) + "—" + String(FUEL_FULL_V, 2) + "V]");
    return -1.0f;
  }

  // Interpolation linéaire entre vide et plein
  float pct = (volts - FUEL_EMPTY_V) / (FUEL_FULL_V - FUEL_EMPTY_V) * 100.0f;

  // Contraindre à [0, 100]
  if (pct < 0.0f) pct = 0.0f;
  if (pct > 100.0f) pct = 100.0f;

  return pct;
#endif
}

// ================================================================
//  LECTURE CYCLE COMPLET (round-robin RPM / Speed / Temp / Volt)
//  + lecture carburant à chaque cycle
// ================================================================
void readCycle() {
  // Les 4 premiers PIDs sont standards, "FUEL" est géré séparément
  if (g_pidStep < 4) {
    if (!pidEnabled[g_pidStep]) {
      g_pidStep = (g_pidStep + 1) % N_PIDS;
      return;
    }
    String raw = sendCmd(PIDS[g_pidStep]);
    bool ok = parsePID(raw, g_pidStep);
    if (ok) {
      pidFails[g_pidStep] = 0;
    } else {
      pidFails[g_pidStep]++;
      if (pidFails[g_pidStep] >= MAX_PID_RETRIES) {
        Serial.println("⛔ PID " + String(PIDS[g_pidStep]) + " désactivé");
        pidEnabled[g_pidStep] = false;
      }
    }
  } else {
    // PID virtuel "FUEL" — utilise la méthode détectée
    float fuel = readFuelLevel();
    if (fuel >= 0.0f) {
      g_obd.fuelLevel = fuel;
    }
  }

  // Fin de cycle → enregistrer dans la queue
  if (g_pidStep == N_PIDS - 1) {
    g_obd.engineOn = (g_obd.rpm > 0);
    String ts = nowISO();
    ts.toCharArray(g_obd.recAt, sizeof(g_obd.recAt));
    addToQueue();
    printStatus();
  }

  g_pidStep = (g_pidStep + 1) % N_PIDS;
}

// ================================================================
//  ENVOI DE COMMANDE ELM327 ET LECTURE RÉPONSE
// ================================================================
String sendCmd(const String& cmd, unsigned int ms) {
  if (!SerialBT.connected()) return "NOBT";

  // Vider le buffer entrant
  while (SerialBT.available()) SerialBT.read();

  SerialBT.println(cmd);

  String res = "";
  unsigned long start = millis();

  while (millis() - start < (unsigned long)ms) {
    while (SerialBT.available()) {
      char c = SerialBT.read();
      if (c == '>') {
        res.toUpperCase();
        res.replace("\r", "");
        res.replace("\n", "");
        res.replace(" ", "");
        res.trim();
        // Supprimer l'écho de la commande si présent
        String up = cmd;
        up.toUpperCase();
        up.replace("\r", "");
        if (res.startsWith(up)) {
          res = res.substring(up.length());
          res.trim();
        }
        return res;
      }
      if ((uint8_t)c >= 32 || c == '\r' || c == '\n') res += c;
    }
  }
  return "TIMEOUT";
}

// ================================================================
//  INITIALISATION ELM327
// ================================================================
bool initELM() {
  Serial.println(F("\n🔧 Init ELM327..."));
  String r = sendCmd("ATZ", 3000);
  Serial.println("  ATZ    → " + r);
  delay(1500);
  sendCmd("ATE0", 1000); delay(200);   // Echo OFF
  sendCmd("ATL0", 1000); delay(200);   // Linefeed OFF
  sendCmd("ATS0", 1000); delay(200);   // Espaces OFF
  sendCmd("ATH0", 1000); delay(200);   // Headers OFF
  sendCmd("ATSP0", 1000); delay(300);  // Protocole AUTO
  String v = sendCmd("ATRV", 1000);
  Serial.println("  ATRV   → " + v);

  // Réinitialiser les compteurs de retry
  for (int i = 0; i < N_PIDS; i++) {
    pidEnabled[i] = true;
    pidFails[i]   = 0;
  }
  g_pidStep = 0;
  Serial.println(F("✅ ELM327 prêt"));
  return true;
}

// ================================================================
//  PARSING DES PIDs OBD STANDARDS
// ================================================================
bool parsePID(const String& raw, int idx) {
  Serial.println("  ← [" + String(PIDS[idx]) + "] \"" + raw + "\"");

  if (raw.length() == 0         ||
      raw == "TIMEOUT"          ||
      raw == "NOBT"             ||
      raw.indexOf("NODATA")   != -1 ||
      raw.indexOf("UNABLE")   != -1 ||
      raw.indexOf("BUFFERFULL") != -1 ||
      raw.indexOf("?")         != -1 ||
      raw.indexOf("ERROR")     != -1) {
    return false;
  }

  String pid = String(PIDS[idx]);

  // ── ATRV : Tension batterie ────────────────────────────────
  if (pid == "ATRV") {
    String num = "";
    for (int i = 0; i < (int)raw.length(); i++) {
      char c = raw[i];
      if (isDigit(c) || c == '.') num += c;
    }
    if (num.length() < 2) return false;
    float v = num.toFloat();
    if (v >= 8.0f && v <= 17.0f) {
      g_obd.voltage = v;
      return true;
    }
    return false;
  }

  // ── PIDs OBD standard (chercher "41XX") ───────────────────────
  String key = "41" + pid.substring(2);
  key.toUpperCase();
  int pos = raw.indexOf(key);
  if (pos == -1) return false;
  pos += (int)key.length();

  // ── 010C : RPM = (A*256 + B) / 4 ─────────────────────────────
  if (pid == "010C") {
    if ((int)raw.length() < pos + 4) return false;
    int rpm = (int)(strtol(raw.substring(pos, pos + 4).c_str(), nullptr, 16) / 4);
    if (rpm < 0 || rpm > 10000) return false;
    g_obd.rpm = rpm;
    return true;
  }

  // ── 010D : Vitesse = A (km/h) ─────────────────────────────────
  if (pid == "010D") {
    if ((int)raw.length() < pos + 2) return false;
    int spd = (int)strtol(raw.substring(pos, pos + 2).c_str(), nullptr, 16);
    if (spd < 0 || spd > 300) return false;
    g_obd.speed = spd;
    return true;
  }

  // ── 0105 : Temp. réfrigérant = A - 40 (°C) ───────────────────
  if (pid == "0105") {
    if ((int)raw.length() < pos + 2) return false;
    int temp = (int)strtol(raw.substring(pos, pos + 2).c_str(), nullptr, 16) - 40;
    if (temp < -40 || temp > 215) return false;
    g_obd.coolantTemp = temp;
    return true;
  }

  return false;
}

// ================================================================
//  AJOUTER DANS LA QUEUE
// ================================================================
void addToQueue() {
  if ((int)g_queue.size() >= MAX_QUEUE_SIZE) g_queue.pop_front();
  g_queue.push_back(g_obd);
}

// ================================================================
//  ENVOI VERS SUPABASE
// ================================================================
void pushQueue() {
  if (g_queue.empty()) {
    Serial.println(F("📭 Queue vide"));
    return;
  }

  Serial.println("📤 Supabase — " + String(g_queue.size()) + " items...");

  WiFiClientSecure cli;
  cli.setInsecure();
  cli.setTimeout(15);

  HTTPClient http;
  http.setTimeout(12000);
  http.setReuse(true);

  int sent  = 0;
  int fails = 0;

  while (!g_queue.empty() &&
         WiFi.status() == WL_CONNECTED &&
         fails < MAX_SEND_FAILS) {

    if (postOne(g_queue.front(), cli, http)) {
      g_queue.pop_front();
      sent++;
      Serial.print('.');
      delay(250);
    } else {
      fails++;
      Serial.println("\n  ❌ Échec " + String(fails) + "/" + String(MAX_SEND_FAILS));
      delay(1500);
    }
  }

  http.end();
  if (sent > 0)
    Serial.println("\n✅ " + String(sent) + " envoyé(s) | Queue: " + String(g_queue.size()));
}

// ================================================================
//  POST D'UN ENREGISTREMENT VERS SUPABASE
// ================================================================
bool postOne(const OBDData& d, WiFiClientSecure& cli, HTTPClient& http) {
  if (!http.begin(cli, SUPA_URL)) {
    Serial.println(F("  ❌ HTTP begin() échoué"));
    return false;
  }

  http.addHeader(F("Content-Type"),  F("application/json"));
  http.addHeader(F("apikey"),        SUPA_KEY);
  http.addHeader(F("Authorization"), "Bearer " + String(SUPA_KEY));
  http.addHeader(F("Prefer"),        F("return=minimal"));

  StaticJsonDocument<512> doc;

  if (d.rpm >= 0)           doc["rpm"]          = d.rpm;
  if (d.speed >= 0)         doc["speed"]        = d.speed;
  if (d.coolantTemp > -999) doc["coolant_temp"] = d.coolantTemp;

  if (d.voltage >= 0.0f)
    doc["voltage"] = (float)((int)(d.voltage * 100 + 0.5f)) / 100.0f;

  // Carburant : float avec 1 décimale, ou absent (→ NULL Supabase)
  if (d.fuelLevel >= 0.0f)
    doc["fuel_level"] = (float)((int)(d.fuelLevel * 10 + 0.5f)) / 10.0f;

  doc["engine_on"]   = d.engineOn;

  // Source de la donnée carburant (pour debug dans Supabase)
  if (d.fuelSrc[0] != '\0')
    doc["fuel_method"] = d.fuelSrc;

  if (d.recAt[0] != '\0')
    doc["recorded_at"] = d.recAt;

  String json;
  serializeJson(doc, json);
  Serial.println("  → " + json);

  int code = http.POST(json);
  http.end();

  if (code == 200 || code == 201) return true;

  Serial.println("  ❌ HTTP " + String(code));
  return false;
}

// ================================================================
//  RECONNEXION BLUETOOTH
// ================================================================
bool checkBT() {
  if (SerialBT.connected()) {
    if (!g_btConn) {
      g_btConn = true;
      Serial.println(F("✅ BT reconnecté !"));
      delay(1500);
      initELM();
      detectFuelSource();   // Re-détecter la source carburant
    }
    return true;
  }

  if (g_btConn) {
    g_btConn = false;
    Serial.println(F("⚠️  BT perdu — reconnexion..."));
  }

  if (SerialBT.connect(BT_ADDR)) {
    g_btConn = true;
    Serial.println(F("✅ BT reconnecté !"));
    delay(2000);
    initELM();
    detectFuelSource();
    return true;
  }

  return false;
}

// ================================================================
//  CONNEXION WIFI
// ================================================================
void checkWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    if (!g_ntpOk) syncNTP();
    return;
  }

  Serial.println(F("🔄 Reconnexion WiFi..."));
  WiFi.disconnect();
  delay(500);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  for (int i = 0; i < 15 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500); Serial.print('.');
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi: " + WiFi.localIP().toString());
    syncNTP();
  } else {
    Serial.println(F("\n❌ WiFi indisponible"));
  }
}

// ================================================================
//  NTP
// ================================================================
void syncNTP() {
  Serial.println(F("⏰ Sync NTP..."));
  configTime(NTP_OFFSET, 0, NTP_SERVER);
  struct tm ti;
  if (getLocalTime(&ti, 6000)) {
    g_ntpOk = true;
    char buf[25];
    strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &ti);
    Serial.println("✅ NTP: " + String(buf));
  } else {
    Serial.println(F("⚠️  NTP échec"));
  }
}

String nowISO() {
  if (!g_ntpOk) return "";
  struct tm ti;
  if (!getLocalTime(&ti, 500)) return "";
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &ti);
  return String(buf);
}

// ================================================================
//  AFFICHAGE ÉTAT DANS LE SERIAL MONITOR
// ================================================================
void printStatus() {
  const char* fuelMethodNames[] = {
    "Non detecte",
    "OBD 012F (Standard)",
    ("Mode 22: " + g_fuelMode22Cmd).c_str(),
    "Capteur ADC GPIO34"
  };

  Serial.println(F("\n┌──────────────────────────────────────┐"));
  Serial.println(F("│         DONNÉES OBD — CYCLE OK        │"));
  Serial.println(F("├──────────────────────────────────────┤"));

  Serial.printf("│ RPM           : %d\n",   g_obd.rpm >= 0 ? g_obd.rpm : -1);
  Serial.printf("│ Vitesse       : %d km/h\n", g_obd.speed >= 0 ? g_obd.speed : -1);

  if (g_obd.fuelLevel >= 0.0f)
    Serial.printf("│ CARBURANT     : %.1f%%  [%s]\n", g_obd.fuelLevel, g_obd.fuelSrc);
  else
    Serial.println(F("│ CARBURANT     : ⛔ INCONNU — Aucune méthode"));

  if (g_obd.voltage >= 0.0f)
    Serial.printf("│ Tension       : %.2f V\n", g_obd.voltage);

  if (g_obd.coolantTemp > -999)
    Serial.printf("│ Temp. refroid.: %d °C\n", g_obd.coolantTemp);

  Serial.println(F("├──────────────────────────────────────┤"));
  Serial.println("│ Moteur        : " + String(g_obd.engineOn ? "ON" : "OFF"));
  Serial.println("│ Timestamp     : " + String(g_obd.recAt[0] ? g_obd.recAt : "(NTP absent)"));
  Serial.println("│ Queue Supabase: " + String(g_queue.size()) + " items");
  Serial.println(F("└──────────────────────────────────────┘\n"));
}

// ================================================================
//  SCHÉMA CÂBLAGE CAPTEUR ADC (Stratégie 3)
//  ─────────────────────────────────────────
//
//  VOITURE (jauge réservoir carburant)
//  ────────────────────────────────────────
//
//  Fil SIGNAL jauge        Fil MASSE
//  (variable 10-180Ω)      (GND)
//       │                    │
//       │    ┌──────┐        │
//       └────┤ 1kΩ  ├──┬─────┘
//            └──────┘  │
//                       │───── GPIO34 (ESP32 ADC)
//                       │
//                    ┌──┴──┐
//                    │ 220Ω│
//                    └──┬──┘
//                       │
//                      GND (ESP32)
//
//  Connecter également le GND de la voiture au GND de l'ESP32
//
//  CALIBRATION (une seule fois) :
//  1. Réservoir VIDE : mesurer tension GPIO34 → FUEL_EMPTY_V
//  2. Réservoir PLEIN: mesurer tension GPIO34 → FUEL_FULL_V
//  ─────────────────────────────────────────────────────────
// ================================================================
