"""
══════════════════════════════════════════════════════════════════════════════
🧠 FleetGuard AI — Entraînement du Modèle de Machine Learning
══════════════════════════════════════════════════════════════════════════════

📝 Description :
    Ce script simule des données de conduite réaliste pour entraîner un
    modèle de Machine Learning capable de prédire :
      1. Le risque de fatigue du chauffeur (0% → 100%)
      2. Le risque de conduite dangereuse (0% → 100%)
      3. Le score de santé moteur (0% → 100%)

🔧 Technologies :
    - Python 3.8+ / NumPy / Scikit-Learn
    - TensorFlow 2.x / Keras
    - Export en TensorFlow Lite (.tflite)

💡 Note : Ce script est optionnel. Le FleetAiEngine Dart embarqué dans
   l'application Flutter fonctionne déjà avec un algorithme multi-critères
   avancé sans avoir besoin du fichier .tflite. Ce script permet cependant
   de démontrer la méthodologie ML complète pour le rapport de PFE.

  Pour lancer :
    pip install numpy tensorflow scikit-learn matplotlib
    python train_fatigue.py

  Auteur : FleetGuard AI Team
  Date : Avril 2026
══════════════════════════════════════════════════════════════════════════════
"""

import os
import json
import numpy as np

# ── Vérification des dépendances ──
try:
    import tensorflow as tf
    from tensorflow import keras
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import mean_absolute_error, r2_score
    HAS_TF = True
except ImportError:
    HAS_TF = False
    print("⚠️  TensorFlow/scikit-learn non installé.")
    print("   Pour installer : pip install tensorflow scikit-learn")
    print("   Le modèle Dart natif dans Flutter fonctionne sans ce script.")
    print()

# ══════════════════════════════════════════════════════════════════════════
#  1. GÉNÉRATION DU DATASET SYNTHÉTIQUE (15 000 trajets simulés)
# ══════════════════════════════════════════════════════════════════════════

print("=" * 70)
print("🧠 FleetGuard AI — Génération du Dataset d'Entraînement")
print("=" * 70)

NUM_SAMPLES = 15000
np.random.seed(42)

# Features (12 variables d'entrée)
# 0: drive_duration_hours     (0.1  → 14.0)
# 1: hour_of_day              (0.0  → 23.9)
# 2: avg_rpm                  (600  → 4500)
# 3: avg_speed_kmh            (0    → 140)
# 4: harsh_brake_count        (0    → 30)
# 5: overspeed_count          (0    → 20)
# 6: coolant_temp_c           (60   → 130)
# 7: oil_pressure_bar         (0.5  → 5.0)
# 8: fuel_level_pct           (5    → 100)
# 9: ambient_temp_c           (5    → 45)
# 10: engine_load_pct         (10   → 100)
# 11: dtc_count               (0    → 10)

FEATURE_NAMES = [
    "duration_hours", "hour_of_day", "avg_rpm", "avg_speed",
    "harsh_brakes", "overspeeds", "coolant_temp", "oil_pressure",
    "fuel_level", "ambient_temp", "engine_load", "dtc_count"
]

X = np.zeros((NUM_SAMPLES, 12))
y_fatigue = np.zeros(NUM_SAMPLES)
y_driving_risk = np.zeros(NUM_SAMPLES)
y_engine_health = np.zeros(NUM_SAMPLES)

for i in range(NUM_SAMPLES):
    # ── Générer les features ──
    duration = np.random.exponential(3.0) + 0.1  # Distribution exponentielle réaliste
    duration = min(duration, 14.0)
    hour = np.random.uniform(0, 24)
    rpm = np.random.normal(1800, 500)
    rpm = np.clip(rpm, 600, 4500)
    speed = np.random.normal(65, 25)
    speed = np.clip(speed, 0, 140)
    brakes = np.random.poisson(2)  # Distribution de Poisson (événements rares)
    brakes = min(brakes, 30)
    overspeeds = np.random.poisson(1)
    overspeeds = min(overspeeds, 20)
    coolant = np.random.normal(88, 10)
    coolant = np.clip(coolant, 60, 130)
    oil_pressure = np.random.normal(3.0, 0.8)
    oil_pressure = np.clip(oil_pressure, 0.5, 5.0)
    fuel = np.random.uniform(5, 100)
    ambient = np.random.normal(25, 8)
    ambient = np.clip(ambient, 5, 45)
    engine_load = np.random.normal(55, 20)
    engine_load = np.clip(engine_load, 10, 100)
    dtc = np.random.choice([0, 0, 0, 0, 0, 1, 1, 2, 3, 5])  # Majorité sans erreurs

    X[i] = [duration, hour, rpm, speed, brakes, overspeeds,
            coolant, oil_pressure, fuel, ambient, engine_load, dtc]

    # ════════════════════════════════════════════════════════════════
    #  Labels : Calcul des scores de vérité terrain (Ground Truth)
    # ════════════════════════════════════════════════════════════════

    # ── Score de Fatigue ──
    fatigue = 0.0
    # Durée (facteur principal)
    if duration <= 1.0:
        fatigue += 0.0
    elif duration <= 3.0:
        fatigue += (duration - 1.0) / 8.0
    elif duration <= 4.5:
        fatigue += 0.25 + ((duration - 3.0) / 1.5) ** 1.5 * 0.25
    else:
        fatigue += 0.5 + min((duration - 4.5) / 5.0, 0.5)

    # Rythme circadien
    if 2 <= hour <= 6:
        fatigue += 0.3 * np.sin((hour - 2) / 4 * np.pi)
    elif 14 <= hour <= 16:
        fatigue += 0.15
    elif hour >= 22 or hour <= 1:
        fatigue += 0.2

    # Événements (signe de micro-sommeils)
    fatigue += brakes * 0.01 + overspeeds * 0.005

    # Chaleur
    if ambient > 32:
        fatigue += (ambient - 32) / 50.0

    fatigue += np.random.normal(0, 0.03)
    y_fatigue[i] = np.clip(fatigue, 0, 1)

    # ── Score de Risque de Conduite ──
    risk = 0.0
    if speed > 90:
        risk += ((speed - 90) / 50) ** 0.8 * 0.35
    if rpm > 3000:
        risk += ((rpm - 3000) / 1500) * 0.2
    risk += brakes / 30.0 * 0.2
    risk += overspeeds / 20.0 * 0.15
    risk += y_fatigue[i] * 0.3  # La fatigue amplifie le risque
    risk += np.random.normal(0, 0.02)
    y_driving_risk[i] = np.clip(risk, 0, 1)

    # ── Score de Santé Moteur (inversé : 1 = parfait) ──
    health = 1.0
    if coolant > 105:
        health -= (coolant - 105) / 50.0
    if oil_pressure < 1.5:
        health -= (1.5 - oil_pressure) / 2.0
    health -= dtc * 0.05
    if engine_load > 85:
        health -= (engine_load - 85) / 100.0
    health += np.random.normal(0, 0.02)
    y_engine_health[i] = np.clip(health, 0, 1)

print(f"✅ Dataset généré : {NUM_SAMPLES} échantillons × {len(FEATURE_NAMES)} features")
print(f"   Fatigue   — min: {y_fatigue.min():.2f}, max: {y_fatigue.max():.2f}, moy: {y_fatigue.mean():.2f}")
print(f"   Risque    — min: {y_driving_risk.min():.2f}, max: {y_driving_risk.max():.2f}, moy: {y_driving_risk.mean():.2f}")
print(f"   Moteur    — min: {y_engine_health.min():.2f}, max: {y_engine_health.max():.2f}, moy: {y_engine_health.mean():.2f}")
print()

# ══════════════════════════════════════════════════════════════════════════
#  2. NORMALISATION MinMax
# ══════════════════════════════════════════════════════════════════════════

mins = X.min(axis=0).tolist()
maxs = X.max(axis=0).tolist()

X_norm = (X - mins) / (np.array(maxs) - np.array(mins) + 1e-8)

print(f"✅ Normalisation MinMax appliquée")

# ══════════════════════════════════════════════════════════════════════════
#  3. ENTRAÎNEMENT (si TensorFlow est disponible)
# ══════════════════════════════════════════════════════════════════════════

if HAS_TF:
    print()
    print("=" * 70)
    print("🧠 Entraînement du Réseau de Neurones (Multi-Output)")
    print("=" * 70)

    # Combiner les 3 outputs
    y_combined = np.column_stack([y_fatigue, y_driving_risk, y_engine_health])

    X_train, X_test, y_train, y_test = train_test_split(
        X_norm, y_combined, test_size=0.2, random_state=42
    )

    # ── Architecture du réseau ──
    model = keras.Sequential([
        keras.layers.Dense(64, activation='relu', input_shape=(12,)),
        keras.layers.BatchNormalization(),
        keras.layers.Dropout(0.2),
        keras.layers.Dense(32, activation='relu'),
        keras.layers.BatchNormalization(),
        keras.layers.Dropout(0.15),
        keras.layers.Dense(16, activation='relu'),
        keras.layers.Dense(3, activation='sigmoid')  # 3 outputs : fatigue, risk, health
    ])

    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='mse',
        metrics=['mae']
    )

    print(model.summary())

    # Entraînement avec early stopping
    callbacks = [
        keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True),
        keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=3)
    ]

    history = model.fit(
        X_train, y_train,
        epochs=50,
        batch_size=64,
        validation_split=0.15,
        callbacks=callbacks,
        verbose=1
    )

    # ── Évaluation ──
    y_pred = model.predict(X_test)

    print()
    print("=" * 70)
    print("📊 Résultats de l'Évaluation")
    print("=" * 70)

    for idx, label in enumerate(["Fatigue", "Risque Conduite", "Santé Moteur"]):
        mae = mean_absolute_error(y_test[:, idx], y_pred[:, idx])
        r2 = r2_score(y_test[:, idx], y_pred[:, idx])
        print(f"   {label:20s} — MAE: {mae:.4f}  |  R²: {r2:.4f}")

    # ── Export TFLite ──
    print()
    print("Conversion en TensorFlow Lite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()

    os.makedirs('../assets/ai_models', exist_ok=True)
    tflite_path = '../assets/ai_models/fleetguard_model.tflite'
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    print(f"✅ Modèle TFLite sauvegardé : {tflite_path} ({len(tflite_model)} bytes)")

    # Sauvegarder les paramètres de normalisation
    meta = {
        "version": "2.0",
        "features": FEATURE_NAMES,
        "outputs": ["fatigue_risk", "driving_risk", "engine_health"],
        "mins": mins,
        "maxs": maxs,
        "num_samples": NUM_SAMPLES,
        "architecture": "Dense(64→32→16→3) + BN + Dropout"
    }
    with open('../assets/ai_models/model_meta.json', 'w') as f:
        json.dump(meta, f, indent=2)
    print(f"✅ Métadonnées JSON sauvegardées")

else:
    print()
    print("=" * 70)
    print("📊 Statistiques du Dataset (sans TensorFlow)")
    print("=" * 70)
    print()
    print("ℹ️  Le modèle TFLite n'a pas été généré (TensorFlow non installé).")
    print("   Ce n'est PAS un problème : l'application Flutter utilise le")
    print("   FleetAiEngine Dart natif qui fonctionne sans fichier .tflite.")
    print()
    print("   Pour générer le modèle TFLite (optionnel) :")
    print("     pip install tensorflow scikit-learn")
    print("     python train_fatigue.py")

print()
print("=" * 70)
print("✅ FleetGuard AI — Script terminé avec succès !")
print("=" * 70)
