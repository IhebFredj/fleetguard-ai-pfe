// ================================================================
//  ESP32 OBD-II Fleet Tracker — Version FINALE V10
//  Corrections:
//    - Lecture cycle complet avant addToQueue()
//    - Suppression condition rpm>200 / volt>13 (bloquait tout)
//    - Fuel level envoyé en float (pas int), NULL si inconnu
//    - Reconnexion BT automatique dans loop()
//    - NTP timestamps ISO 8601 → colonne recorded_at Supabase
//    - Vérification longueur réponse avant substring()
//    - s += searchKey.length() au lieu de s += 4 hardcodé
//    - Logs Serial complets pour diagnostic
//
//  ⚠️  SUPABASE : Ajouter ces colonnes si absentes :
//      ALTER TABLE obd_data
//        ADD COLUMN IF NOT EXISTS engine_on   BOOLEAN,
//        ADD COLUMN IF NOT EXISTS recorded_at TIMESTAMPTZ;
// ================================================================

#include <BluetoothSerial.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <deque>
#include <time.h>

// ================================================================
// CONFIGURATION — modifier selon votre installation
// ================================================================
BluetoothSerial SerialBT;

uint8_t     BT_ADDR[6]    = {0x00, 0x10, 0xCC, 0x4F, 0x36, 0x03};
const char* BT_PIN        = "1234";

const char* WIFI_SSID     = "TOPNET_1688";
const char* WIFI_PASS     = "nkzasot8c3";

const char* SUPA_URL      = "https://obwbtsgibyvbmslzrbwu.supabase.co/rest/v1/obd_data";
const char* SUPA_KEY      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9id2J0c2dpYnl2Ym1zbHpyYnd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzMzM4MzUsImV4cCI6MjA4ODkwOTgzNX0.3rDQcB_ZGa0SJs-qSJ2AjmyxjZj3r2e4caiGZhzSoLE";

// Tunisie = UTC+1, pas de changement d'heure
const long  NTP_GMT_OFFSET    = 3600;
const int   NTP_DST_OFFSET    = 0;
const char* NTP_SERVER        = "pool.ntp.org";

// Intervalles
const unsigned long INTERVAL_QUERY    = 1200;   // ms entre chaque PID
const unsigned long INTERVAL_PUSH     = 10000;  // ms entre chaque envoi Supabase
const unsigned long INTERVAL_BT_CHECK = 5000;   // ms entre chaque check BT

const int MAX_QUEUE_SIZE  = 200;
const int MAX_PID_RETRIES = 3;   // Echecs consécutifs avant désactivation PID
const int MAX_SEND_FAILS  = 3;   // Echecs HTTP avant abandon de la session

// ================================================================
// STRUCTURE DE DONNÉES OBD
// ================================================================
struct OBDData {
  int   rpm         = -1;     // -1 = non lu
  int   speed       = -1;
  float fuelLevel   = -1.0f;  // -1 = non disponible (PID non supporté)
  float voltage     = -1.0f;
  int   coolantTemp = -999;   // -999 = non lu
  bool  engineOn    = false;
  char  recAt[25]   = {0};    // ISO 8601 timestamp, vide si NTP non sync
};

// ================================================================
// VARIABLES GLOBALES
// ================================================================
std::deque<OBDData> g_queue;
OBDData             g_obd;   // Données OBD courantes (accumulées sur le cycle)

bool g_btConn   = false;
bool g_ntpOk    = false;

// Round-robin PID
const int    N_PIDS                = 5;
const char*  PIDS[N_PIDS]         = {"010C", "010D", "012F", "0105", "ATRV"};
bool         pidEnabled[N_PIDS]   = {true, true, true, true, true};
int          pidFails[N_PIDS]     = {0, 0, 0, 0, 0};
int          g_pidStep            = 0;

unsigned long g_tQuery   = 0;
unsigned long g_tPush    = 0;
unsigned long g_tBTCheck = 0;

// ================================================================
// PROTOTYPES
// ================================================================
String sendCmd(const String& cmd, unsigned int timeoutMs = 1500);
bool   initELM();
bool   parsePID(const String& raw, int idx);
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
// SETUP
// ================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println(F("\n╔══════════════════════════════════╗"));
  Serial.println(F("║  OBD FLEET TRACKER — V10 FINAL   ║"));
  Serial.println(F("╚══════════════════════════════════╝\n"));

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
    Serial.println(F("\n⚠️  WiFi non disponible au démarrage"));
  }

  // ── Bluetooth ─────────────────────────────────────────────────
  Serial.println(F("🔵 Connexion BT OBD..."));
  SerialBT.setPin(BT_PIN, 4);
  SerialBT.begin("ESP32_Fleet", true);
  delay(500);

  if (SerialBT.connect(BT_ADDR)) {
    g_btConn = true;
    Serial.println(F("✅ BT OBD connecté !"));
    delay(2000);
    initELM();
  } else {
    Serial.println(F("⚠️  BT non connecté — retry automatique dans loop()"));
  }
}

// ================================================================
// LOOP
// ================================================================
void loop() {
  unsigned long now = millis();

  // ── Vérification BT (toutes les 5s) ──────────────────────────
  if (now - g_tBTCheck >= INTERVAL_BT_CHECK) {
    checkBT();
    g_tBTCheck = now;
  }

  // ── Lecture OBD (1 PID par tick) ─────────────────────────────
  if (g_btConn && (now - g_tQuery >= INTERVAL_QUERY)) {
    readCycle();
    g_tQuery = now;
  }

  // ── Envoi Supabase ────────────────────────────────────────────
  if (now - g_tPush >= INTERVAL_PUSH) {
    checkWiFi();  // S'assure que le WiFi est actif avant d'envoyer
    if (WiFi.status() == WL_CONNECTED) {
      pushQueue();
    } else {
      Serial.println("⚠️  WiFi absent — " + String(g_queue.size()) + " items en attente");
    }
    g_tPush = now;
  }
}

// ================================================================
// LECTURE D'UN PID (round-robin, un par tick)
// ================================================================
void readCycle() {
  // Sauter les PIDs désactivés
  if (!pidEnabled[g_pidStep]) {
    g_pidStep = (g_pidStep + 1) % N_PIDS;
    return;
  }

  String raw = sendCmd(PIDS[g_pidStep]);
  bool   ok  = parsePID(raw, g_pidStep);

  if (ok) {
    pidFails[g_pidStep] = 0;
  } else {
    pidFails[g_pidStep]++;
    if (pidFails[g_pidStep] >= MAX_PID_RETRIES) {
      Serial.println("⛔ PID " + String(PIDS[g_pidStep]) +
                     " désactivé (non supporté par ce véhicule)");
      pidEnabled[g_pidStep] = false;
      // Fuel inconnu → garder -1.0 (sera envoyé NULL à Supabase)
    }
  }

  // ── FIN DU CYCLE COMPLET → sauvegarder ───────────────────────
  // CORRECTION CRITIQUE : on n'enregistre QU'APRÈS avoir lu TOUS les PIDs
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
// ENVOI COMMANDE ELM327 + LECTURE RÉPONSE
// ================================================================
String sendCmd(const String& cmd, unsigned int timeoutMs) {
  if (!SerialBT.connected()) return F("NOBT");

  // Vider le buffer entrant
  while (SerialBT.available()) SerialBT.read();

  SerialBT.println(cmd);

  String       res   = "";
  unsigned long start = millis();

  while (millis() - start < timeoutMs) {
    while (SerialBT.available()) {
      char c = SerialBT.read();
      if (c == '>') {
        // Nettoyage de la réponse
        res.toUpperCase();
        res.replace("\r", "");
        res.replace("\n", "");
        res.replace(" ", "");
        res.trim();
        // Supprimer l'écho de la commande si présent
        String cmdUp = cmd;
        cmdUp.toUpperCase();
        cmdUp.replace("\r", "");
        cmdUp.replace("\n", "");
        if (res.startsWith(cmdUp)) {
          res = res.substring(cmdUp.length());
          res.trim();
        }
        return res;
      }
      // Accumuler si caractère affichable ou fin de ligne
      if ((uint8_t)c >= 32 || c == '\r' || c == '\n') {
        res += c;
      }
    }
  }

  return F("TIMEOUT");
}

// ================================================================
// INITIALISATION ELM327
// ================================================================
bool initELM() {
  Serial.println(F("🔧 Init ELM327..."));

  String r = sendCmd("ATZ", 3000);
  Serial.println("  ATZ    → " + r);
  delay(1500);

  sendCmd("ATE0", 1000); delay(200);  // Echo OFF
  sendCmd("ATL0", 1000); delay(200);  // Linefeed OFF
  sendCmd("ATS0", 1000); delay(200);  // Espaces OFF
  sendCmd("ATH0", 1000); delay(200);  // Headers OFF
  sendCmd("ATSP0", 1000); delay(300); // Protocole AUTO

  // Vérification : lecture tension batterie
  String v = sendCmd("ATRV", 1000);
  Serial.println("  ATRV   → " + v);

  // Réinitialiser compteurs de retry
  for (int i = 0; i < N_PIDS; i++) {
    pidEnabled[i] = true;
    pidFails[i]   = 0;
  }
  g_pidStep = 0;

  Serial.println(F("✅ ELM327 prêt\n"));
  return true;
}

// ================================================================
// PARSING DES RÉPONSES OBD
// Retourne true si données valides extraites, false sinon
// ================================================================
bool parsePID(const String& raw, int idx) {
  String pid = String(PIDS[idx]);
  Serial.println("  ← [" + pid + "] \"" + raw + "\"");

  // ── Détection des erreurs ─────────────────────────────────────
  if (raw.length() == 0         ||
      raw == F("TIMEOUT")       ||
      raw == F("NOBT")          ||
      raw.indexOf("NODATA")   != -1 ||
      raw.indexOf("UNABLE")   != -1 ||
      raw.indexOf("BUFFERFULL") != -1 ||
      raw.indexOf("CANERROR") != -1 ||
      raw.indexOf("BUSERROR")  != -1 ||
      raw.indexOf("STOPRESP")  != -1 ||
      raw.indexOf("?")         != -1 ||
      raw.indexOf("ERROR")     != -1) {
    return false;
  }

  // ── ATRV : tension batterie (réponse directe, ex: "12.4V") ───
  if (pid == "ATRV") {
    String num = "";
    for (int i = 0; i < (int)raw.length(); i++) {
      char c = raw[i];
      if (isDigit(c) || c == '.') num += c;
    }
    if (num.length() < 2) return false;
    float v = num.toFloat();
    if (v < 8.0f || v > 17.0f) return false; // Hors plage réaliste
    g_obd.voltage = v;
    return true;
  }

  // ── PIDs OBD standard : chercher "41XX" dans la réponse ──────
  // pid = "010C" → searchKey = "410C"
  String key = "41" + pid.substring(2);
  key.toUpperCase();

  int pos = raw.indexOf(key);
  if (pos == -1) {
    Serial.println("    ⚠️  Header '" + key + "' absent dans: \"" + raw + "\"");
    return false;
  }

  // CORRECTION: utiliser key.length() au lieu de +4 hardcodé
  int dataStart = pos + (int)key.length();

  // ── 010C : RPM = (A*256 + B) / 4 ────────────────────────────
  if (pid == "010C") {
    if ((int)raw.length() < dataStart + 4) {
      Serial.println(F("    ⚠️  RPM: réponse trop courte"));
      return false;
    }
    long val = strtol(raw.substring(dataStart, dataStart + 4).c_str(), nullptr, 16);
    int  rpm = (int)(val / 4);
    if (rpm < 0 || rpm > 10000) return false;
    g_obd.rpm = rpm;
    return true;
  }

  // ── 010D : Vitesse = A (km/h) ────────────────────────────────
  if (pid == "010D") {
    if ((int)raw.length() < dataStart + 2) {
      Serial.println(F("    ⚠️  Speed: réponse trop courte"));
      return false;
    }
    int spd = (int)strtol(raw.substring(dataStart, dataStart + 2).c_str(), nullptr, 16);
    if (spd < 0 || spd > 300) return false;
    g_obd.speed = spd;
    return true;
  }

  // ── 012F : Niveau carburant = A * 100.0 / 255.0 (%) ─────────
  //    C'est LE PID le plus important — debug maximal
  if (pid == "012F") {
    if ((int)raw.length() < dataStart + 2) {
      Serial.println(F("    ⚠️  Fuel: réponse trop courte"));
      return false;
    }
    String hexByte = raw.substring(dataStart, dataStart + 2);
    Serial.println("    🔍 Fuel raw hex byte: '" + hexByte + "'");
    long rawByte = strtol(hexByte.c_str(), nullptr, 16);
    // Valeur attendue: 0x00 = 0%, 0xFF = 100%
    if (rawByte < 0 || rawByte > 255) {
      Serial.println(F("    ⚠️  Fuel: valeur hors plage 0-255"));
      return false;
    }
    float fuel = (rawByte * 100.0f) / 255.0f;
    if (fuel < 0.0f || fuel > 100.0f) return false;
    g_obd.fuelLevel = fuel;
    Serial.println("    ⛽ Carburant: " + String(fuel, 1) + "%");
    return true;
  }

  // ── 0105 : Temp. liquide refroidissement = A - 40 (°C) ───────
  if (pid == "0105") {
    if ((int)raw.length() < dataStart + 2) {
      Serial.println(F("    ⚠️  Coolant: réponse trop courte"));
      return false;
    }
    int temp = (int)strtol(raw.substring(dataStart, dataStart + 2).c_str(), nullptr, 16) - 40;
    if (temp < -40 || temp > 215) return false;
    g_obd.coolantTemp = temp;
    return true;
  }

  return false;
}

// ================================================================
// AJOUTER DANS LA FILE D'ATTENTE
// ================================================================
void addToQueue() {
  if ((int)g_queue.size() >= MAX_QUEUE_SIZE) {
    g_queue.pop_front(); // Supprimer le plus ancien si queue pleine
  }
  g_queue.push_back(g_obd);
}

// ================================================================
// ENVOI DE LA FILE VERS SUPABASE
// ================================================================
void pushQueue() {
  if (g_queue.empty()) {
    Serial.println(F("📭 Queue vide, rien à envoyer"));
    return;
  }

  Serial.println("📤 Envoi Supabase — " + String(g_queue.size()) + " items en attente...");

  WiFiClientSecure cli;
  cli.setInsecure();      // ⚠️ Prodution: utiliser setCACert() pour valider le cert
  cli.setTimeout(15);     // 15 secondes

  HTTPClient http;
  http.setTimeout(12000);
  http.setReuse(true);    // Réutiliser la connexion TCP entre les requêtes

  int sent  = 0;
  int fails = 0;

  while (!g_queue.empty() &&
         WiFi.status() == WL_CONNECTED &&
         fails < MAX_SEND_FAILS)
  {
    if (postOne(g_queue.front(), cli, http)) {
      g_queue.pop_front();
      sent++;
      Serial.print('.');
      delay(250); // Délai minimal entre requêtes
    } else {
      fails++;
      Serial.println("\n  ❌ Échec " + String(fails) + "/" + String(MAX_SEND_FAILS));
      delay(1500);
    }
  }

  http.end();

  if (sent > 0) {
    Serial.println("\n✅ " + String(sent) + " envoyé(s) | Queue restante: " +
                   String(g_queue.size()));
  }
  if (fails >= MAX_SEND_FAILS) {
    Serial.println(F("⚠️  Envoi interrompu — les données restent en queue"));
  }
}

// ================================================================
// POST D'UN SEUL ENREGISTREMENT VERS SUPABASE
// ================================================================
bool postOne(const OBDData& d, WiFiClientSecure& cli, HTTPClient& http) {
  if (!http.begin(cli, SUPA_URL)) {
    Serial.println(F("  ❌ HTTP begin() échoué"));
    return false;
  }

  http.addHeader(F("Content-Type"),  F("application/json"));
  http.addHeader(F("apikey"),        SUPA_KEY);
  http.addHeader(F("Authorization"), "Bearer " + String(SUPA_KEY));
  http.addHeader(F("Prefer"),        F("return=minimal")); // Pas de retour JSON → économise bande passante

  // ── Construction du JSON ──────────────────────────────────────
  StaticJsonDocument<512> doc;

  // Champs numériques : envoyés seulement s'ils ont été lus correctement
  if (d.rpm >= 0)           doc["rpm"]          = d.rpm;
  if (d.speed >= 0)         doc["speed"]        = d.speed;
  if (d.coolantTemp > -999) doc["coolant_temp"] = d.coolantTemp;

  // Tension : arrondie à 2 décimales
  if (d.voltage >= 0.0f) {
    doc["voltage"] = (float)((int)(d.voltage * 100 + 0.5f)) / 100.0f;
  }

  // CARBURANT : float avec 1 décimale, NULL (omis) si non disponible
  // ArduinoJson omet le champ si non défini → Supabase insère NULL
  if (d.fuelLevel >= 0.0f) {
    doc["fuel_level"] = (float)((int)(d.fuelLevel * 10 + 0.5f)) / 10.0f;
    //                   ex: 73.7254... → 73.7
  }
  // Si fuelLevel == -1 : le champ n'est PAS ajouté → Supabase = NULL ✓

  doc["engine_on"] = d.engineOn;

  // Timestamp ISO 8601 si NTP synchronisé
  if (d.recAt[0] != '\0') {
    doc["recorded_at"] = d.recAt;
  }

  String json;
  serializeJson(doc, json);
  Serial.println("  → " + json); // Debug — retirer en production si trop verbeux

  int code = http.POST(json);
  http.end();

  if (code == 200 || code == 201) return true;

  Serial.println("  ❌ HTTP " + String(code));
  // Lire la réponse d'erreur Supabase pour diagnostic
  // (Note: http.getString() doit être appelé avant http.end(), trop tard ici)
  // → Déplacer http.end() après getString() si besoin de debugging
  return false;
}

// ================================================================
// VÉRIFICATION ET RECONNEXION BLUETOOTH
// ================================================================
bool checkBT() {
  if (SerialBT.connected()) {
    if (!g_btConn) {
      // Vient de se reconnecter
      g_btConn = true;
      Serial.println(F("✅ BT reconnecté !"));
      delay(1500);
      initELM();
    }
    return true;
  }

  if (g_btConn) {
    g_btConn = false;
    Serial.println(F("⚠️  BT perdu — tentative reconnexion..."));
  }

  if (SerialBT.connect(BT_ADDR)) {
    g_btConn = true;
    Serial.println(F("✅ BT reconnecté !"));
    delay(2000);
    initELM();
    return true;
  }

  Serial.println(F("❌ BT reconnexion échouée"));
  return false;
}

// ================================================================
// VÉRIFICATION ET RECONNEXION WIFI
// ================================================================
void checkWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    if (!g_ntpOk) syncNTP(); // Essayer NTP si pas encore sync
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
// SYNCHRONISATION NTP
// ================================================================
void syncNTP() {
  Serial.println(F("⏰ Sync NTP..."));
  configTime(NTP_GMT_OFFSET, NTP_DST_OFFSET, NTP_SERVER);
  struct tm ti;
  if (getLocalTime(&ti, 6000)) {
    g_ntpOk = true;
    char buf[25];
    strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &ti);
    Serial.println("✅ NTP OK: " + String(buf));
  } else {
    Serial.println(F("⚠️  NTP échec — timestamps vides"));
  }
}

// ================================================================
// TIMESTAMP ISO 8601 COURANT
// ================================================================
String nowISO() {
  if (!g_ntpOk) return "";
  struct tm ti;
  if (!getLocalTime(&ti, 500)) return "";
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &ti);
  return String(buf);
}

// ================================================================
// AFFICHAGE ÉTAT COURANT SUR SERIAL
// ================================================================
void printStatus() {
  Serial.println(F("\n┌────────────────────────────────────┐"));
  Serial.println(F("│         DONNÉES OBD — CYCLE OK     │"));
  Serial.println(F("├────────────────────────────────────┤"));

  if (g_obd.rpm >= 0)
    Serial.println("│ RPM           : " + String(g_obd.rpm));
  else
    Serial.println(F("│ RPM           : — (non lu)"));

  if (g_obd.speed >= 0)
    Serial.println("│ Vitesse       : " + String(g_obd.speed) + " km/h");
  else
    Serial.println(F("│ Vitesse       : — (non lu)"));

  if (g_obd.fuelLevel >= 0.0f)
    Serial.println("│ Carburant     : " + String(g_obd.fuelLevel, 1) + " %");
  else
    Serial.println(F("│ Carburant     : INCONNU (PID 012F non supporté)"));

  if (g_obd.voltage >= 0.0f)
    Serial.println("│ Tension       : " + String(g_obd.voltage, 2) + " V");
  else
    Serial.println(F("│ Tension       : — (non lu)"));

  if (g_obd.coolantTemp > -999)
    Serial.println("│ Temp. refroid.: " + String(g_obd.coolantTemp) + " °C");
  else
    Serial.println(F("│ Temp. refroid.: — (non lu)"));

  Serial.println("│ Moteur        : " + String(g_obd.engineOn ? "ON" : "OFF"));
  Serial.println("│ Timestamp     : " + String(g_obd.recAt[0] ? g_obd.recAt : "(pas NTP)"));
  Serial.println("│ Queue         : " + String(g_queue.size()) + " items");
  Serial.println(F("└────────────────────────────────────┘\n"));
}
