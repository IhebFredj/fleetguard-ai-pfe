# FleetGuard AI — ESP32 OBD-II Firmware

## Matériel nécessaire
- **ESP32 DevKit** (n'importe quel modèle avec Bluetooth + Wi-Fi)
- **Adaptateur OBD-II ELM327 Bluetooth** (Classic SPP, pas BLE)
- Câble USB pour programmer l'ESP32

## Configuration

Ouvrez `esp32_obd.ino` et modifiez les constantes en haut du fichier :

```cpp
// Wi-Fi de votre réseau
const char* WIFI_SSID     = "Oppo reno 8t 5G";//OU "TOPNET_1688"
const char* WIFI_PASSWORD = "11111111";//OU "nkzasot8c3"

// UUID du camion dans Supabase
const char* CAMION_ID     = "votre-uuid-camion";

// Nom Bluetooth de votre adaptateur ELM327
const char* ELM327_NAME   = "OBDII";

// Capacité du réservoir (pour estimation carburant)
const float TANK_CAPACITY_L = 80.0;
```

## Installation Arduino IDE

1. **Board Manager** : Ajoutez l'URL ESP32 dans Préférences :
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
2. **Installer** : "ESP32 by Espressif Systems" dans le Board Manager
3. **Bibliothèques** : Installez `ArduinoJson` (par Benoît Blanchon, v6+)
4. **Sélectionner** : Board → "ESP32 Dev Module"
5. **Compiler & Téléverser**

## Fonctionnement

### Boucles de priorité

| Boucle | Fréquence | PIDs lus |
|--------|-----------|----------|
| **FAST** | Chaque cycle (~500ms) | RPM (010C), Vitesse (010D) |
| **MEDIUM** | Tous les 3 cycles (~1.5s) | Temp (0105), Charge (0104), MAF (0110), Fuel Rate (015E), TPS (0111) |
| **SLOW** | Tous les 10 cycles (~5s) | Fuel Level (012F), Batterie (0142), IAT (010F), MAP (010B), Pédale (015A) |
| **RARE** | Tous les 30 cycles (~15s) | Temp Ambiante (0146), Baro (0133), Type Carburant (0151), etc. |

### Estimation de carburant (quand PID 012F non supporté)

Le firmware utilise une **stratégie en cascade** :

1. **PID 015E** (Fuel Rate direct) → Meilleure source
2. **MAF (PID 0110)** → Calcul : `débit_carburant = MAF / AFR / densité`
3. **Charge moteur + RPM** → Estimation approximative basée sur le régime
4. **Ralenti par défaut** → 0.8 L/h pour diesel

Le niveau de carburant estimé part de 50% et diminue en fonction de la consommation cumulée.

### Distance

Calculée par **intégration de la vitesse** : `distance += vitesse × Δt`
Avec `Δt` mesuré en temps réel (pas un intervalle fixe).

## LED de statut

| État | LED |
|------|-----|
| Bluetooth déconnecté | Clignotement rapide |
| Connecté + lecture | Clignotement lent (heartbeat) |
| Erreur | Éteinte |

## Envoi des données

Les données sont envoyées à Supabase **toutes les 5 secondes** via l'API REST.
Le payload JSON correspond exactement au schéma utilisé par l'application Flutter.

## Dépannage

- **"Failed to connect to ELM327"** : Assurez-vous que l'adaptateur est alimenté (contact mis) et appairé avec l'ESP32.
- **"NO DATA" sur 0100** : Le protocole n'est pas détecté automatiquement. Le firmware essaie tous les protocoles CAN/ISO.
- **Wi-Fi déconnecté** : Le firmware tente de se reconnecter automatiquement.
- **Fuel Level = -1** : Le PID 012F n'est pas supporté → l'estimation prend le relais automatiquement.
