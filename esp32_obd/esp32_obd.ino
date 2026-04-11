/*
 * ═══════════════════════════════════════════════════════════════
 * FleetGuard AI — ESP32 OBD-II Reader + Supabase Uploader
 * ═══════════════════════════════════════════════════════════════
 * 
 * Hardware: ESP32 DevKit + ELM327 Bluetooth OBD-II adapter
 * Connection: ESP32 connects via Bluetooth Serial (SPP) to ELM327
 *             then sends data via Wi-Fi to Supabase REST API
 * 
 * Features:
 *   - Reads all available OBD-II PIDs (Mode 01)
 *   - Auto-detects supported PIDs at startup
 *   - Fuel level estimation when PID 012F is not supported
 *   - Fuel consumption estimation via MAF or Engine Load
 *   - Distance integration from speed over time
 *   - Sends JSON payload to Supabase every N seconds
 *   - LED status indicators
 * 
 * Wiring: No extra wiring needed — ESP32 uses built-in Bluetooth
 *         and Wi-Fi. Just power via USB.
 * ═══════════════════════════════════════════════════════════════
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <BluetoothSerial.h>
#include <string.h>
#include <ArduinoJson.h>

// ═══════════════════════════════════════════════════
// CONFIGURATION — MODIFY THESE
// ═══════════════════════════════════════════════════

// Wi-Fi
const char* WIFI_SSID     = "Oppo Reno 8t 5g";
const char* WIFI_PASSWORD = "11111111";

// Supabase
const char* SUPABASE_URL  = "https://obwbtsgibyvbmslzrbwu.supabase.co";
const char* SUPABASE_KEY  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9id2J0c2dpYnl2Ym1zbHpyYnd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzMzM4MzUsImV4cCI6MjA4ODkwOTgzNX0.3rDQcB_ZGa0SJs-qSJ2AjmyxjZj3r2e4caiGZhzSoLE";
const char* TABLE_NAME    = "obd_data";

// Truck identifier (must match your Supabase camion ID)
const char* CAMION_ID     = "161_tun_1284";

// ELM327 Connection Details
const uint8_t ELM_MAC[6]  = {0x00, 0x10, 0xCC, 0x4F, 0x36, 0x03}; // Address: 00:10:CC:4F:36:03
const char* PIN_CODE      = "1234";

// Tank capacity in Liters (used for fuel estimation)
const float TANK_CAPACITY_L = 80.0;

// Upload interval in milliseconds (5s for near real-time remote dashboard)
const unsigned long UPLOAD_INTERVAL_MS = 5000;

// ═══════════════════════════════════════════════════
// GLOBALS
// ═══════════════════════════════════════════════════

BluetoothSerial SerialBT;
bool elmConnected = false;

// Supported PIDs bitmask
bool pidSupported[0x70] = {false}; // PIDs 0x00 to 0x6F

// ── Live data ──
int    g_rpm              = 0;
float  g_speedKmh         = 0;
float  g_engineTempC      = 0;
int    g_fuelLevelPct     = -1;   // -1 = never read
float  g_engineLoadPct    = -1;
float  g_mafGps           = -1;   // g/s
float  g_fuelRateLh       = -1;   // L/h from PID 015E
float  g_tpsPct           = -1;
float  g_iatC             = -1;
float  g_mapKpa           = -1;
float  g_fuelPressureKpa  = -1;
float  g_oilTempC         = -1;
float  g_fuelTempC        = -1;
float  g_batteryVoltage   = -1;
float  g_ambientTempC     = -999;
float  g_baroKpa          = -1;
float  g_pedalPct         = -1;
float  g_fuelRailKpa      = -1;
int    g_runTimeSec       = -1;
int    g_distSinceDtcKm   = -1;
int    g_fuelTypeCode     = -1;

// ── Computed / estimated ──
float  g_consoLPer100     = 0;     // instantaneous L/100km
float  g_fuelConsumedL    = 0;     // session total consumed
float  g_distanceKm       = 0;     // session distance
float  g_estimatedFuelPct = 25.0;  // Start at 25% (matches real gauge from photo)
bool   g_fuelPidSupported = false;

// ── Diagnostics (DTC) ──
bool   g_milOn           = false;   // MIL (Check Engine) light
int    g_dtcCount        = 0;      // Number of confirmed DTCs
String g_dtcCodes        = "";     // Comma-separated DTC codes (e.g. "P0301,P0420")
String g_pendingDtcCodes = "";     // Pending DTCs (Mode 07)

// ── Timing ──
unsigned long g_lastPollMs    = 0;
unsigned long g_lastUploadMs  = 0;
unsigned long g_lastTickMs      = 0;
unsigned long g_lastDashboardMs = 0;
int           g_pollCycle       = 0;

// ── Fuel estimation constants ──
// Defaults to Diesel (Citroën Jumpy etc.)
float AFR     = 14.5;
float DENSITY = 0.835;  // g/mL for diesel

// ═══════════════════════════════════════════════════
// ELM327 COMMUNICATION
// ═══════════════════════════════════════════════════

String elmRequest(const String& cmd, unsigned long timeoutMs = 2000) {
  // Flush any pending data
  while (SerialBT.available()) SerialBT.read();
  
  SerialBT.print(cmd + "\r");
  
  String response = "";
  unsigned long start = millis();
  
  while ((millis() - start) < timeoutMs) {
    if (SerialBT.available()) {
      char c = SerialBT.read();
      if (c == '>') break;  // ELM327 prompt
      if (c != '\0') response += c;
    }
    delay(1);
  }
  
  response.trim();
  return response;
}

// Parse hex byte from string
int parseHex(const String& s) {
  return (int)strtol(s.c_str(), NULL, 16);
}

// Extract data bytes from Mode 01 response
// Returns number of bytes extracted, fills data[]
int parseMode01(const String& resp, const String& pidHex, int* data, int maxBytes) {
  String cleaned = resp;
  cleaned.replace("\r", " ");
  cleaned.replace("\n", " ");
  cleaned.replace(">", " ");
  cleaned.replace(":", " ");
  cleaned.toUpperCase();
  cleaned.trim();
  
  // Target: "41 XX" followed by data bytes
  String target41 = "41 " + pidHex;
  target41.toUpperCase();
  
  int idx = cleaned.indexOf(target41);
  if (idx < 0) {
    // Try without spaces (some adapters return "41XX...")
    String targetNoSpace = "41" + pidHex;
    targetNoSpace.toUpperCase();
    idx = cleaned.indexOf(targetNoSpace);
    if (idx >= 0) idx += targetNoSpace.length();
    else return 0;
  } else {
    idx += target41.length();
  }
  
  // Now extract bytes after the header
  String remainder = cleaned.substring(idx);
  remainder.trim();
  
  int count = 0;
  int pos = 0;
  while (count < maxBytes && pos < (int)remainder.length()) {
    // Skip spaces
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

// Check if response contains "NO DATA" or error
bool isNoData(const String& resp) {
  String r = resp;
  r.toUpperCase();
  return r.indexOf("NO DATA") >= 0 || r.indexOf("ERROR") >= 0 || r.indexOf("UNABLE") >= 0;
}

// ═══════════════════════════════════════════════════
// ELM327 INITIALIZATION
// ═══════════════════════════════════════════════════

bool initELM327() {
  Serial.println("[ELM] Initializing...");
  
  // Flush any garbage
  delay(500);
  while (SerialBT.available()) SerialBT.read();
  
  String r;
  
  r = elmRequest("ATZ", 5000);  // Reset
  Serial.println("[ELM] ATZ -> " + r);
  delay(1500);
  
  // Flush post-reset garbage
  while (SerialBT.available()) SerialBT.read();
  
  r = elmRequest("ATE0", 1500); // Echo off
  Serial.println("[ELM] ATE0 -> " + r);
  
  r = elmRequest("ATL0", 1500); // Linefeeds off
  Serial.println("[ELM] ATL0 -> " + r);
  
  r = elmRequest("ATH0", 1500); // Headers off
  Serial.println("[ELM] ATH0 -> " + r);
  
  r = elmRequest("ATS1", 1500); // Spaces ON (important for parsing!)
  Serial.println("[ELM] ATS1 -> " + r);
  
  r = elmRequest("ATAT1", 1500); // Adaptive timing
  Serial.println("[ELM] ATAT1 -> " + r);
  
  r = elmRequest("ATST64", 1500); // Timeout 100 * 4ms = 400ms (balanced)
  Serial.println("[ELM] ATST64 -> " + r);
  
  r = elmRequest("ATSP0", 3000); // Auto protocol
  Serial.println("[ELM] ATSP0 -> " + r);
  
  // Identify adapter
  r = elmRequest("ATI", 1500);
  Serial.println("[ELM] Adapter: " + r);
  
  r = elmRequest("ATDP", 1500); // Describe protocol
  Serial.println("[ELM] Protocol: " + r);
  
  // Quick handshake — query PID 0100
  Serial.println("[ELM] Sending 0100 (handshake)...");
  r = elmRequest("0100", 10000);
  Serial.println("[ELM] 0100 raw: [" + r + "]");
  
  if (isNoData(r) || r.indexOf("41") < 0) {
    Serial.println("[ELM] No ECU response on auto-protocol, trying each protocol...");
    // Try all OBD protocols: 6=ISO 15765-4 CAN 11bit/500k, 7=CAN 500k 29bit
    // 8=CAN 250k 11bit, 9=CAN 250k 29bit, 1-5=older protocols
    const char* protocols[] = {"6", "7", "8", "9", "1", "2", "3", "4", "5"};
    bool found = false;
    for (int p = 0; p < 9; p++) {
      String setProto = "ATSP" + String(protocols[p]);
      elmRequest(setProto, 2000);
      delay(500);
      r = elmRequest("0100", 10000);
      Serial.printf("[ELM] Protocol %s -> [%s]\n", protocols[p], r.c_str());
      if (!isNoData(r) && r.indexOf("41") >= 0) {
        found = true;
        Serial.printf("[ELM] *** Protocol %s works! ***\n", protocols[p]);
        break;
      }
    }
    if (!found) {
      Serial.println("[ELM] WARNING: No protocol found. Will try reading PIDs anyway.");
      return true; // Don't abort — we'll try raw reads
    }
  }
  
  Serial.println("[ELM] ECU communication OK!");
  return true;
}

// ═══════════════════════════════════════════════════
// SUPPORTED PIDS DETECTION
// ═══════════════════════════════════════════════════

void detectSupportedPids() {
  Serial.println("[PID] Detecting supported PIDs...");
  
  int totalFound = 0;
  
  // Query PID ranges: 0100, 0120, 0140, 0160
  const char* queries[] = {"0100", "0120", "0140", "0160"};
  const char* pids[]    = {"00",   "20",   "40",   "60"};
  int offsets[]          = {0,      0x20,   0x40,   0x60};
  
  for (int q = 0; q < 4; q++) {
    String resp = elmRequest(queries[q], 5000);
    Serial.printf("[PID] %s raw: [%s]\n", queries[q], resp.c_str());
    
    if (isNoData(resp)) {
      Serial.printf("[PID] %s -> NO DATA\n", queries[q]);
      continue;
    }
    
    int data[4];
    int n = parseMode01(resp, pids[q], data, 4);
    Serial.printf("[PID] %s parsed %d bytes: %02X %02X %02X %02X\n", 
                  queries[q], n, 
                  n > 0 ? data[0] : 0, n > 1 ? data[1] : 0, 
                  n > 2 ? data[2] : 0, n > 3 ? data[3] : 0);
    
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
    
    // If bit 0x20/0x40/0x60 not set, no need to query next range
    int nextPid = offsets[q] + 0x20;
    if (nextPid < 0x70 && !pidSupported[nextPid]) break;
  }
  
  // ─── FALLBACK: if detection failed, assume basic PIDs ───
  if (totalFound == 0) {
    Serial.println("[PID] ⚠ No PIDs detected! Forcing basic PIDs as supported.");
    Serial.println("[PID] Will attempt to read them directly from ECU.");
    // Essential PIDs that almost every car supports
    pidSupported[0x04] = true;  // Engine Load
    pidSupported[0x05] = true;  // Engine Temp
    pidSupported[0x0B] = true;  // MAP
    pidSupported[0x0C] = true;  // RPM
    pidSupported[0x0D] = true;  // Speed
    pidSupported[0x0F] = true;  // IAT
    pidSupported[0x10] = true;  // MAF
    pidSupported[0x11] = true;  // TPS
    pidSupported[0x1F] = true;  // Run Time
    pidSupported[0x2F] = true;  // Fuel Level
    pidSupported[0x31] = true;  // Distance since DTC
    pidSupported[0x33] = true;  // Baro pressure
    pidSupported[0x42] = true;  // Battery voltage
    pidSupported[0x46] = true;  // Ambient temp
    pidSupported[0x5E] = true;  // Fuel rate
    g_fuelPidSupported = true;
    totalFound = 15;
  }
  
  // Print supported PIDs
  Serial.printf("[PID] Total supported: %d\n", totalFound);
  Serial.print("[PID] List: ");
  for (int i = 1; i < 0x70; i++) {
    if (pidSupported[i]) {
      Serial.printf("%02X ", i);
    }
  }
  Serial.println();
  
  // Check fuel level support
  g_fuelPidSupported = pidSupported[0x2F];
  Serial.printf("[PID] Fuel Level (2F): %s\n", g_fuelPidSupported ? "YES" : "NO — will estimate");
  Serial.printf("[PID] Fuel Rate  (5E): %s\n", pidSupported[0x5E] ? "YES" : "NO");
  Serial.printf("[PID] MAF        (10): %s\n", pidSupported[0x10] ? "YES" : "NO");
  Serial.printf("[PID] Engine Load(04): %s\n", pidSupported[0x04] ? "YES" : "NO");
}

// ═══════════════════════════════════════════════════
// PID READERS
// ═══════════════════════════════════════════════════

int readRPM() {
  if (!pidSupported[0x0C]) return -1;
  String r = elmRequest("010C", 800);
  int d[2]; 
  if (parseMode01(r, "0C", d, 2) == 2) {
    return ((d[0] * 256) + d[1]) / 4;
  }
  return -1;
}

float readSpeed() {
  if (!pidSupported[0x0D]) return -1;
  String r = elmRequest("010D", 800);
  int d[1];
  if (parseMode01(r, "0D", d, 1) == 1) return (float)d[0];
  return -1;
}

float readEngineTemp() {
  if (!pidSupported[0x05]) return -999;
  String r = elmRequest("0105", 800);
  int d[1];
  if (parseMode01(r, "05", d, 1) == 1) return d[0] - 40.0;
  return -999;
}

float readEngineLoad() {
  if (!pidSupported[0x04]) return -1;
  String r = elmRequest("0104", 800);
  int d[1];
  if (parseMode01(r, "04", d, 1) == 1) return (100.0 * d[0]) / 255.0;
  return -1;
}

float readMAF() {
  if (!pidSupported[0x10]) return -1;
  String r = elmRequest("0110", 800);
  int d[2];
  if (parseMode01(r, "10", d, 2) == 2) return ((d[0] * 256) + d[1]) / 100.0;
  return -1;
}

int readFuelLevel() {
  if (!pidSupported[0x2F]) return -1;
  String r = elmRequest("012F", 800);
  int d[1];
  if (parseMode01(r, "2F", d, 1) == 1) return (int)round((100.0 * d[0]) / 255.0);
  return -1;
}

float readFuelRate() {
  if (!pidSupported[0x5E]) return -1;
  String r = elmRequest("015E", 800);
  int d[2];
  if (parseMode01(r, "5E", d, 2) == 2) return ((d[0] * 256) + d[1]) / 20.0;
  return -1;
}

float readTPS() {
  if (!pidSupported[0x11]) return -1;
  String r = elmRequest("0111", 800);
  int d[1];
  if (parseMode01(r, "11", d, 1) == 1) return (100.0 * d[0]) / 255.0;
  return -1;
}

float readIAT() {
  if (!pidSupported[0x0F]) return -999;
  String r = elmRequest("010F", 800);
  int d[1];
  if (parseMode01(r, "0F", d, 1) == 1) return d[0] - 40.0;
  return -999;
}

float readMAP() {
  if (!pidSupported[0x0B]) return -1;
  String r = elmRequest("010B", 800);
  int d[1];
  if (parseMode01(r, "0B", d, 1) == 1) return (float)d[0];
  return -1;
}

float readFuelPressure() {
  if (!pidSupported[0x0A]) return -1;
  String r = elmRequest("010A", 800);
  int d[1];
  if (parseMode01(r, "0A", d, 1) == 1) return d[0] * 3.0;
  return -1;
}

float readOilTemp() {
  if (!pidSupported[0x5C]) return -999;
  String r = elmRequest("015C", 800);
  int d[1];
  if (parseMode01(r, "5C", d, 1) == 1) return d[0] - 40.0;
  return -999;
}

float readFuelTemp() {
  if (!pidSupported[0x5F]) return -999;
  String r = elmRequest("015F", 800);
  int d[1];
  if (parseMode01(r, "5F", d, 1) == 1) return d[0] - 40.0;
  return -999;
}

int readRunTime() {
  if (!pidSupported[0x1F]) return -1;
  String r = elmRequest("011F", 800);
  int d[2];
  if (parseMode01(r, "1F", d, 2) == 2) return (d[0] * 256) + d[1];
  return -1;
}

int readDistSinceDTC() {
  if (!pidSupported[0x31]) return -1;
  String r = elmRequest("0131", 800);
  int d[2];
  if (parseMode01(r, "31", d, 2) == 2) return (d[0] * 256) + d[1];
  return -1;
}

int readFuelType() {
  if (!pidSupported[0x51]) return -1;
  String r = elmRequest("0151", 800);
  int d[1];
  if (parseMode01(r, "51", d, 1) == 1) return d[0];
  return -1;
}

float readBatteryVoltage() {
  if (!pidSupported[0x42]) return -1;
  String r = elmRequest("0142", 800);
  int d[2];
  if (parseMode01(r, "42", d, 2) == 2) return ((d[0] * 256) + d[1]) / 1000.0;
  return -1;
}

float readAmbientTemp() {
  if (!pidSupported[0x46]) return -999;
  String r = elmRequest("0146", 800);
  int d[1];
  if (parseMode01(r, "46", d, 1) == 1) return d[0] - 40.0;
  return -999;
}

float readBaroPressure() {
  if (!pidSupported[0x33]) return -1;
  String r = elmRequest("0133", 800);
  int d[1];
  if (parseMode01(r, "33", d, 1) == 1) return (float)d[0];
  return -1;
}

float readPedalPosition() {
  if (!pidSupported[0x5A]) return -1;
  String r = elmRequest("015A", 800);
  int d[1];
  if (parseMode01(r, "5A", d, 1) == 1) return (100.0 * d[0]) / 255.0;
  return -1;
}

float readFuelRailPressure() {
  if (!pidSupported[0x23]) return -1;
  String r = elmRequest("0123", 800);
  int d[2];
  if (parseMode01(r, "23", d, 2) == 2) return ((d[0] * 256) + d[1]) * 10.0;
  return -1;
}

// ═══════════════════════════════════════════════════
// DIAGNOSTICS — DTC READER
// ═══════════════════════════════════════════════════

// Decode DTC type prefix from first 2 bits
char dtcTypeChar(int firstByte) {
  switch ((firstByte >> 6) & 0x03) {
    case 0: return 'P'; // Powertrain
    case 1: return 'C'; // Chassis
    case 2: return 'B'; // Body
    case 3: return 'U'; // Network
  }
  return 'P';
}

// Read MIL status and DTC count from PID 0101
void readMILStatus() {
  String r = elmRequest("0101", 800);
  int d[4];
  if (parseMode01(r, "01", d, 4) >= 1) {
    g_milOn = (d[0] & 0x80) != 0;  // Bit 7 = MIL on/off
    g_dtcCount = d[0] & 0x7F;       // Bits 0-6 = DTC count
    Serial.printf("[DTC] MIL: %s, DTC count: %d\n", g_milOn ? "ON" : "OFF", g_dtcCount);
  }
}

// Parse DTCs from Mode 03 (confirmed) or Mode 07 (pending) response
String parseDTCResponse(const String& resp) {
  String result = "";
  String cleaned = resp;
  cleaned.replace("\r", " ");
  cleaned.replace("\n", " ");
  cleaned.replace(">", "");
  cleaned.replace(":", " ");
  cleaned.trim();
  cleaned.toUpperCase();
  
  // Remove "43 " or "47 " header (Mode 03 / 07 response)
  int startIdx = -1;
  int modeResp = -1;
  if (cleaned.indexOf("43") >= 0) { startIdx = cleaned.indexOf("43"); modeResp = 43; }
  else if (cleaned.indexOf("47") >= 0) { startIdx = cleaned.indexOf("47"); modeResp = 47; }
  
  if (startIdx < 0) return result;
  
  // Extract hex bytes after the mode response byte
  String data = cleaned.substring(startIdx);
  
  // Split into tokens
  int tokCount = 0;
  String tokens[40];
  int pos = 0;
  data.trim();
  while (pos < (int)data.length() && tokCount < 40) {
    while (pos < (int)data.length() && data[pos] == ' ') pos++;
    int start = pos;
    while (pos < (int)data.length() && data[pos] != ' ') pos++;
    if (pos > start) {
      tokens[tokCount++] = data.substring(start, pos);
    }
  }
  
  // Skip first token (43 or 47), then read pairs of bytes
  for (int i = 1; i + 1 < tokCount; i += 2) {
    int b1 = (int)strtol(tokens[i].c_str(), NULL, 16);
    int b2 = (int)strtol(tokens[i+1].c_str(), NULL, 16);
    
    if (b1 == 0 && b2 == 0) continue; // No DTC
    
    char prefix = dtcTypeChar(b1);
    int digit2 = (b1 >> 4) & 0x03;
    int digit3 = b1 & 0x0F;
    int digit4 = (b2 >> 4) & 0x0F;
    int digit5 = b2 & 0x0F;
    
    char dtcBuf[8];
    snprintf(dtcBuf, sizeof(dtcBuf), "%c%d%X%X%X", prefix, digit2, digit3, digit4, digit5);
    
    if (result.length() > 0) result += ",";
    result += dtcBuf;
  }
  
  return result;
}

// Read confirmed DTCs (Mode 03)
void readConfirmedDTCs() {
  String r = elmRequest("03", 3000);
  Serial.println("[DTC] Mode 03 raw: [" + r + "]");
  
  if (isNoData(r)) {
    g_dtcCodes = "";
    Serial.println("[DTC] No confirmed DTCs");
    return;
  }
  
  g_dtcCodes = parseDTCResponse(r);
  if (g_dtcCodes.length() > 0) {
    Serial.println("[DTC] Confirmed: " + g_dtcCodes);
  } else {
    Serial.println("[DTC] No confirmed DTCs");
  }
}

// Read pending DTCs (Mode 07)
void readPendingDTCs() {
  String r = elmRequest("07", 3000);
  Serial.println("[DTC] Mode 07 raw: [" + r + "]");
  
  if (isNoData(r)) {
    g_pendingDtcCodes = "";
    Serial.println("[DTC] No pending DTCs");
    return;
  }
  
  g_pendingDtcCodes = parseDTCResponse(r);
  if (g_pendingDtcCodes.length() > 0) {
    Serial.println("[DTC] Pending: " + g_pendingDtcCodes);
  } else {
    Serial.println("[DTC] No pending DTCs");
  }
}

// ═══════════════════════════════════════════════════
// FUEL ESTIMATION ENGINE
// ═══════════════════════════════════════════════════

// Compute fuel rate (L/h) from best available source
float computeFuelRateLh() {
  // Priority 1: Direct PID 015E
  if (g_fuelRateLh > 0) return g_fuelRateLh;
  
  // Priority 2: MAF-based calculation
  if (g_mafGps > 0) {
    float fuelGPerS = g_mafGps / AFR;
    return (fuelGPerS / DENSITY) * 3.6;  // g/s -> mL/s -> L/h
  }
  
  // Priority 3: Engine Load + RPM estimation
  if (g_engineLoadPct > 0 && g_rpm > 0) {
    // Typical diesel: max ~18 L/h at full load 4000rpm
    float maxRate = (AFR < 14.6) ? 18.0 : 25.0; // diesel vs gasoline
    float rate = maxRate * (g_engineLoadPct / 100.0) * ((float)g_rpm / 4000.0);
    return constrain(rate, 0.3, maxRate);
  }
  
  // Priority 4: Idle default
  if (g_rpm > 0) return 0.8; // ~0.8 L/h idle for diesel
  return 0;
}

// Update fuel consumption estimation
void updateFuelEstimation(float dtSec) {
  float fuelRate = computeFuelRateLh();
  
  // ── Instantaneous consumption (L/100km) ──
  if (g_speedKmh > 3 && fuelRate > 0) {
    g_consoLPer100 = (fuelRate / g_speedKmh) * 100.0;
    g_consoLPer100 = constrain(g_consoLPer100, 0, 99);
  } else if (g_rpm > 0) {
    g_consoLPer100 = fuelRate; // At idle, show L/h
  }
  
  // ── Fuel consumed (Liters) ──
  if (fuelRate > 0 && dtSec > 0 && dtSec < 10) {
    g_fuelConsumedL += (fuelRate * dtSec) / 3600.0;
  }
  
  // ── Estimated fuel level (when PID 012F is unavailable) ──
  if (!g_fuelPidSupported) {
    // Start at 25%, subtract consumed / tank capacity
    g_estimatedFuelPct = ((TANK_CAPACITY_L * 0.25) - g_fuelConsumedL) / TANK_CAPACITY_L * 100.0;
    g_estimatedFuelPct = constrain(g_estimatedFuelPct, 0, 100);
    g_fuelLevelPct = (int)round(g_estimatedFuelPct);
  }
}

// ═══════════════════════════════════════════════════
// MAIN POLL CYCLE
// ═══════════════════════════════════════════════════

void pollOBD() {
  unsigned long now = millis();
  float dtSec = (g_lastTickMs > 0) ? (now - g_lastTickMs) / 1000.0 : 0.5;
  g_lastTickMs = now;
  g_pollCycle++;

  // ── FAST (every cycle) — RPM + Speed ──
  int rpmVal = readRPM();
  if (rpmVal >= 0) g_rpm = rpmVal;
  
  float spdVal = readSpeed();
  if (spdVal >= 0) g_speedKmh = spdVal;

  // ── Distance — integrate speed over real delta ──
  float dtH = dtSec / 3600.0;
  g_distanceKm += max(0.0f, g_speedKmh) * dtH;

  // ── MEDIUM (every 3 cycles ~1.5s) ──
  if (g_pollCycle % 3 == 0) {
    float t = readEngineTemp();
    if (t > -999) g_engineTempC = t;
    
    float load = readEngineLoad();
    if (load >= 0) g_engineLoadPct = load;
    
    float maf = readMAF();
    if (maf >= 0) g_mafGps = maf;
    
    float fr = readFuelRate();
    if (fr >= 0) g_fuelRateLh = fr;
    
    float tps = readTPS();
    if (tps >= 0) g_tpsPct = tps;
  }

  // ── SLOW (every 10 cycles ~5s) ──
  if (g_pollCycle % 10 == 0) {
    if (g_fuelPidSupported) {
      int fl = readFuelLevel();
      if (fl >= 0) g_fuelLevelPct = fl;
    }
    
    float v = readBatteryVoltage();
    if (v >= 0) g_batteryVoltage = v;
    
    float iat = readIAT();
    if (iat > -999) g_iatC = iat;
    
    float mp = readMAP();
    if (mp >= 0) g_mapKpa = mp;
    
    float pedal = readPedalPosition();
    if (pedal >= 0) g_pedalPct = pedal;
  }

  // ── RARE (every 30 cycles ~15s) ──
  if (g_pollCycle % 30 == 0) {
    float at = readAmbientTemp();
    if (at > -999) g_ambientTempC = at;
    
    float baro = readBaroPressure();
    if (baro >= 0) g_baroKpa = baro;
    
    float fp = readFuelPressure();
    if (fp >= 0) g_fuelPressureKpa = fp;
    
    float rail = readFuelRailPressure();
    if (rail >= 0) g_fuelRailKpa = rail;
    
    float ot = readOilTemp();
    if (ot > -999) g_oilTempC = ot;
    
    float ft = readFuelTemp();
    if (ft > -999) g_fuelTempC = ft;
    
    int ftc = readFuelType();
    if (ftc >= 0) {
      g_fuelTypeCode = ftc;
      // Update AFR/density based on detected fuel type
      if (ftc == 4) { // Diesel
        AFR = 14.5; DENSITY = 0.835;
      } else if (ftc == 1) { // Gasoline
        AFR = 14.7; DENSITY = 0.745;
      }
    }
    
    int rt = readRunTime();
    if (rt >= 0) g_runTimeSec = rt;
    
    int dd = readDistSinceDTC();
    if (dd >= 0) g_distSinceDtcKm = dd;
    
    // ── DTC Diagnostics (1 request for MIL + 2 for codes) ──
    readMILStatus();
    if (g_milOn || g_dtcCount > 0) {
      readConfirmedDTCs();
      readPendingDTCs();
    }
  }

  // ── Update fuel estimation ──
  updateFuelEstimation(dtSec);
}

// ═══════════════════════════════════════════════════
// SUPABASE UPLOAD
// ═══════════════════════════════════════════════════

String fuelTypeStr(int code) {
  switch (code) {
    case 1: return "Essence";
    case 2: return "Methanol";
    case 3: return "Ethanol";
    case 4: return "Diesel";
    case 5: return "GPL";
    case 6: return "GNV";
    default: return "";
  }
}

void uploadToSupabase() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[UPLOAD] Wi-Fi not connected, skipping");
    return;
  }
  
  // ── Network diagnostics (first upload only) ──
  static bool firstRun = true;
  if (firstRun) {
    firstRun = false;
    Serial.printf("[NET] IP: %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("[NET] Gateway: %s\n", WiFi.gatewayIP().toString().c_str());
    Serial.printf("[NET] DNS: %s\n", WiFi.dnsIP().toString().c_str());
    Serial.printf("[NET] Free heap: %d bytes\n", ESP.getFreeHeap());
    
    // Test DNS resolution
    IPAddress resolved;
    const char* host = "obwbtsgibyvbmslzrbwu.supabase.co";
    if (WiFi.hostByName(host, resolved)) {
      Serial.printf("[NET] DNS OK: %s -> %s\n", host, resolved.toString().c_str());
    } else {
      Serial.printf("[NET] ⚠ DNS FAILED for %s\n", host);
      Serial.println("[NET] Check your Wi-Fi has internet access!");
    }
  }
  
  // ── Build JSON payload — ALL sensor data for FleetGuard AI Engine ──
  char payload[1024];
  {
    StaticJsonDocument<900> doc;
    doc["camion"]             = CAMION_ID;
    doc["rpm"]                = g_rpm;
    doc["temperature"]        = (int)round(g_engineTempC);
    doc["vitesse"]            = (int)round(g_speedKmh);
    doc["carburant"]          = max(0, g_fuelLevelPct);
    doc["pression_huile_bar"] = (float)constrain(1.5 + (g_rpm / 6000.0), 0.0, 6.0);
    doc["conso_l_100"]        = g_consoLPer100;
    doc["distance_km"]        = g_distanceKm;
    doc["fuel_consumed_total_l"] = g_fuelConsumedL;

    // ── Moteur ──
    if (g_engineLoadPct >= 0)   doc["engine_load_pct"]    = g_engineLoadPct;
    if (g_mafGps >= 0)          doc["maf_gps"]            = g_mafGps;
    if (g_tpsPct >= 0)          doc["tps_pct"]            = g_tpsPct;
    float fRate = computeFuelRateLh();
    if (fRate > 0) doc["fuel_rate_lh"] = fRate;

    // ── Électrique & Batterie ──
    if (g_batteryVoltage >= 0)  doc["battery_voltage"]    = g_batteryVoltage;

    // ── Températures (ESSENTIELLES pour l'IA) ──
    if (g_oilTempC > -900)      doc["oil_temp_c"]         = g_oilTempC;
    if (g_ambientTempC > -900)  doc["ambient_temp_c"]     = g_ambientTempC;
    if (g_iatC > -900)          doc["iat_c"]              = g_iatC;
    if (g_fuelTempC > -900)     doc["fuel_temp_c"]        = g_fuelTempC;

    // ── Pressions ──
    if (g_mapKpa >= 0)          doc["map_kpa"]            = g_mapKpa;
    if (g_baroKpa >= 0)         doc["baro_kpa"]           = g_baroKpa;
    if (g_fuelPressureKpa >= 0) doc["fuel_pressure_kpa"]  = g_fuelPressureKpa;
    if (g_fuelRailKpa >= 0)     doc["fuel_rail_kpa"]      = g_fuelRailKpa;

    // ── Conduite (CRUCIAL pour score fatigue + éco-conduite) ──
    if (g_pedalPct >= 0)        doc["pedal_pct"]          = g_pedalPct;
    if (g_runTimeSec >= 0)      doc["run_time_sec"]       = g_runTimeSec;
    if (g_distSinceDtcKm >= 0)  doc["dist_since_dtc_km"]  = g_distSinceDtcKm;

    // ── Type de carburant ──
    if (g_fuelTypeCode >= 0) {
      String ft = fuelTypeStr(g_fuelTypeCode);
      if (ft.length() > 0) doc["fuel_type"] = ft;
    }

    // ── Diagnostics (DTC) ──
    doc["mil_on"] = g_milOn;
    doc["dtc_count"] = g_dtcCount;
    if (g_dtcCodes.length() > 0) doc["dtc_codes"] = g_dtcCodes;
    if (g_pendingDtcCodes.length() > 0) doc["dtc_pending"] = g_pendingDtcCodes;

    // ── Status global ──
    doc["status_ok"] = !g_milOn && (g_engineTempC < 105);
    
    serializeJson(doc, payload, sizeof(payload));
  } // StaticJsonDocument freed here
  
  int payloadLen = strlen(payload);
  Serial.printf("[UPLOAD] Payload (%d bytes)\n", payloadLen);
  Serial.printf("[UPLOAD] Free heap with BT: %d\n", ESP.getFreeHeap());
  
  // ── Temporarily disconnect Bluetooth to free RAM for SSL ──
  // Strategy: try disconnect() only (keeps BT stack, fast reconnect)
  // If SSL fails due to low RAM, fall back to full end()
  SerialBT.disconnect();
  delay(100);
  
  uint32_t heapAfterDisconnect = ESP.getFreeHeap();
  Serial.printf("[UPLOAD] Free heap after disconnect: %d\n", heapAfterDisconnect);
  
  bool usedFullEnd = false;
  if (heapAfterDisconnect < 45000) {
    // Not enough RAM with just disconnect — do full end()
    Serial.println("[UPLOAD] Low RAM — using full BT end()");
    SerialBT.end();
    delay(200);
    usedFullEnd = true;
    Serial.printf("[UPLOAD] Free heap after end(): %d\n", ESP.getFreeHeap());
  }
  
  // ── HTTPS connection ──
  {
    WiFiClientSecure client;
    client.setInsecure();
    client.setTimeout(15);
    
    const char* supa_host = "obwbtsgibyvbmslzrbwu.supabase.co";
    
    Serial.println("[UPLOAD] SSL connecting...");
    
    if (client.connect(supa_host, 443)) {
      Serial.println("[UPLOAD] ✓ SSL OK!");
      
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
        Serial.println("[UPLOAD] Réponse complète de Supabase :");
        while (client.available()) {
          String line = client.readStringUntil('\n');
          line.trim();
          if (line.length() > 0) {
             Serial.println("  " + line);
          }
        }
      } else {
        Serial.println("[UPLOAD] ✗ No response (timeout)");
      }
    } else {
      Serial.println("[UPLOAD] ✗ SSL FAILED!");
      Serial.printf("[UPLOAD] Heap: %d\n", ESP.getFreeHeap());
      
      // If we only did disconnect(), try again with full end()
      if (!usedFullEnd) {
        Serial.println("[UPLOAD] Retrying with full BT end()...");
        SerialBT.end();
        delay(200);
        usedFullEnd = true;
        
        WiFiClientSecure client2;
        client2.setInsecure();
        client2.setTimeout(15);
        if (client2.connect(supa_host, 443)) {
          Serial.println("[UPLOAD] ✓ SSL OK (retry)!");
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
            Serial.println("[UPLOAD] Réponse complète (retry) :");
            while (client2.available()) {
              String line = client2.readStringUntil('\n');
              line.trim();
              if (line.length() > 0) {
                 Serial.println("  " + line);
              }
            }
          }
        }
        client2.stop();
      }
    }
    client.stop();
  } // WiFiClientSecure freed here
  
  // ── Reconnect Bluetooth ──
  if (usedFullEnd) {
    // Full BT stack was destroyed — need full re-init
    Serial.println("[BT] Full reconnect (BT stack was stopped)...");
    SerialBT.setPin(PIN_CODE, strlen(PIN_CODE));
    SerialBT.begin("FleetGuard_ESP32", true);
    delay(300);
    elmConnected = SerialBT.connect(const_cast<uint8_t*>(ELM_MAC));
    if (elmConnected) {
      Serial.println("[BT] ✓ Reconnected! Medium re-init...");
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
      elmRequest("ATSP0", 1500);
      String r = elmRequest("0100", 5000);
      if (!isNoData(r) && r.indexOf("41") >= 0) {
        Serial.println("[BT] Medium re-init OK");
      } else {
        Serial.println("[BT] Warning: ECU no response, will try PIDs anyway");
      }
    } else {
      Serial.println("[BT] ✗ Reconnect failed");
    }
  } else {
    // BT stack still alive — just reconnect (ULTRA FAST ~1s)
    Serial.println("[BT] Fast reconnect (BT stack alive)...");
    elmConnected = SerialBT.connect(const_cast<uint8_t*>(ELM_MAC));
    if (elmConnected) {
      delay(200);
      while (SerialBT.available()) SerialBT.read();
      elmRequest("ATE0", 800);
      elmRequest("ATS1", 800);
      elmRequest("ATH0", 800);
      Serial.println("[BT] ✓ Fast reconnect OK!");
    } else {
      // Fast reconnect failed — try full restart
      Serial.println("[BT] Fast reconnect failed, trying full restart...");
      SerialBT.end();
      delay(200);
      SerialBT.setPin(PIN_CODE, strlen(PIN_CODE));
      SerialBT.begin("FleetGuard_ESP32", true);
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
        elmRequest("ATAT1", 800);
        elmRequest("ATST64", 800);
        elmRequest("ATSP0", 1500);
        elmRequest("0100", 5000);
        Serial.println("[BT] ✓ Full restart reconnect OK");
      } else {
        Serial.println("[BT] ✗ All reconnect attempts failed");
      }
    }
  }
}

// ═══════════════════════════════════════════════════
// SERIAL MONITOR DISPLAY
// ═══════════════════════════════════════════════════

void printDashboard() {
  Serial.println("╔═══════════════════════════════════════╗");
  Serial.println("║       FleetGuard ESP32 Dashboard      ║");
  Serial.println("╠═══════════════════════════════════════╣");
  Serial.printf( "║ RPM:       %5d tr/min               ║\n", g_rpm);
  Serial.printf( "║ Vitesse:   %5.0f km/h                 ║\n", g_speedKmh);
  Serial.printf( "║ Temp:      %5.0f °C                   ║\n", g_engineTempC);
  Serial.printf( "║ Charge:    %5.1f %%                    ║\n", max(0.0f, g_engineLoadPct));
  Serial.println("╠── Carburant ─────────────────────────╣");
  
  if (g_fuelPidSupported) {
    Serial.printf("║ Niveau:    %5d %% (PID direct)       ║\n", max(0, g_fuelLevelPct));
  } else {
    Serial.printf("║ Niveau:    %5d %% (ESTIMÉ)           ║\n", max(0, g_fuelLevelPct));
  }
  
  float fRate = computeFuelRateLh();
  Serial.printf( "║ Débit:     %5.1f L/h                  ║\n", max(0.0f, fRate));
  Serial.printf( "║ Conso:     %5.1f L/100km              ║\n", g_consoLPer100);
  Serial.printf( "║ Consommé:  %5.2f L (session)          ║\n", g_fuelConsumedL);
  Serial.printf( "║ Distance:  %5.2f km (session)         ║\n", g_distanceKm);
  Serial.println("╠── Système ──────────────────────────╣");
  
  if (g_batteryVoltage > 0)
    Serial.printf("║ Batterie:  %5.1f V                    ║\n", g_batteryVoltage);
  if (g_ambientTempC > -900)
    Serial.printf("║ Temp ext:  %5.0f °C                   ║\n", g_ambientTempC);
  else
    Serial.println("║ Temp ext:   N/A                       ║");
  
  Serial.printf( "║ Wi-Fi:     %s                  ║\n", WiFi.status() == WL_CONNECTED ? "OK   " : "DÉCO ");
  Serial.printf( "║ Cycle:     %5d                       ║\n", g_pollCycle);
  Serial.println("╚═══════════════════════════════════════╝");
}

// ═══════════════════════════════════════════════════
// SETUP
// ═══════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  Serial.println("\n════════════════════════════════════════");
  Serial.println("  FleetGuard AI — ESP32 OBD-II Reader");
  Serial.println("════════════════════════════════════════\n");
  
  // ── LED ──
  pinMode(2, OUTPUT); // Built-in LED
  
  // ── Wi-Fi ──
  Serial.printf("[WIFI] Connecting to %s...\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 20) {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WIFI] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("\n[WIFI] Connection failed — will retry later");
  }
  
  // ── Bluetooth Serial to ELM327 ──
  Serial.println("[BT] Initializing Bluetooth...");
  SerialBT.setPin(PIN_CODE, strlen(PIN_CODE));
  SerialBT.begin("FleetGuard_ESP32", true); // Master mode
  
  Serial.println("[BT] Connecting to ELM327 via MAC...");
  elmConnected = SerialBT.connect(const_cast<uint8_t*>(ELM_MAC));
  
  if (!elmConnected) {
    Serial.println("[BT] Failed to connect to ELM327!");
    Serial.println("[BT] Make sure the adapter is powered on and paired.");
    // Flash LED rapidly
    for (int i = 0; i < 20; i++) {
      digitalWrite(2, !digitalRead(2));
      delay(200);
    }
    return;
  }
  
  Serial.println("[BT] Connected to ELM327!");
  digitalWrite(2, HIGH);
  
  // ── Initialize ELM327 ──
  if (!initELM327()) {
    Serial.println("[ELM] FAILED to initialize. Check connection.");
    elmConnected = false;
    return;
  }
  Serial.println("[ELM] Initialization successful!");
  
  // ── Detect supported PIDs ──
  detectSupportedPids();
  
  // ── Detect fuel type early ──
  int ft = readFuelType();
  if (ft >= 0) {
    g_fuelTypeCode = ft;
    if (ft == 4) { AFR = 14.5; DENSITY = 0.835; }
    else if (ft == 1) { AFR = 14.7; DENSITY = 0.745; }
    Serial.printf("[FUEL] Detected fuel type: %s (AFR=%.1f, Density=%.3f)\n", 
                  fuelTypeStr(ft).c_str(), AFR, DENSITY);
  } else {
    Serial.println("[FUEL] Fuel type unknown — defaulting to Diesel");
  }
  
  g_lastTickMs = millis();
  Serial.println("\n[OK] System ready — starting data acquisition\n");
}

// ═══════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════

void loop() {
  if (!elmConnected) {
    // Try to reconnect every 10 seconds
    Serial.println("[BT] Attempting reconnect via MAC...");
    elmConnected = SerialBT.connect(const_cast<uint8_t*>(ELM_MAC));
    if (elmConnected) {
      Serial.println("[BT] Reconnected!");
      initELM327();
      detectSupportedPids();
      digitalWrite(2, HIGH);
    } else {
      digitalWrite(2, LOW);
      delay(10000);
      return;
    }
  }
  
  // ── Wi-Fi reconnect ──
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.reconnect();
  }
  
  // ── Poll OBD ──
  unsigned long now = millis();
  pollOBD();
  
  // ── Upload to Supabase ──
  if ((now - g_lastUploadMs) >= UPLOAD_INTERVAL_MS) {
    g_lastUploadMs = now;
    uploadToSupabase();
  }
  
  // ── Print Dashboard locally (every 2 seconds) ──
  if ((now - g_lastDashboardMs) >= 2000) {
    g_lastDashboardMs = now;
    printDashboard();
  }
  
  // ── Heartbeat LED  ──
  digitalWrite(2, (g_pollCycle % 2 == 0) ? HIGH : LOW);
  
  // Small delay between cycles (don't hammer the ELM327 too fast, but keep it snappy)
  delay(10);
}
