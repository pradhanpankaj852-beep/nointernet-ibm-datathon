# Team NoInternet_IBM Z Datathon 2026 Project: NoInternet

> **Decentralized P2P field disaster mesh client communicating with an IBM LinuxONE s390x emergency AI triage engine.**

---

## 🌟 Executive Summary

**NoInternet** is a mission-critical emergency disaster response platform engineered for scenarios where traditional telecommunication, cellular grids, and internet backbones fail.

The solution operates as a **two-tier hybrid system**:
1. **Edge P2P Field Mesh (Mobile)**: Flutter-based mobile application utilizing device-to-device local wireless radios (Wi-Fi Direct, Bluetooth LE, and Near-Field Mesh Clustering). Features **0 KB persistent disk storage (RAM-only hygiene)** and **end-to-end encryption (ECDH P-256 + AES-256-GCM)**.
2. **Centralized Mainframe Triage Backend (IBM LinuxONE)**: Hosted on the IBM LinuxONE Community Cloud (`s390x` mainframe architecture), running a real-time NLP classification engine that ingests opportunistic satellite/uplink distress packets, scores urgency (Priority 1–5), categorizes emergencies (*Medical/Trauma*, *Entrapment/Rescue*, *Infrastructure*, *Supplies*, *Safe Check-in*), and dynamically maintains a prioritized dispatch queue with sub-2ms inference latency.

---

## 🏗️ Architecture Overview

```
                                  +------------------------------------+
                                  |    IBM LinuxONE Community Cloud    |
                                  |     (s390x Mainframe Engine)       |
                                  |                                    |
                                  |  - FastAPI Ingestion Engine        |
                                  |  - TF-IDF + Calibrated ML Model    |
                                  |  - Priority Queue (P1 -> P5)       |
                                  |  - Hardware Accelerated Inference  |
                                  +-----------------+------------------+
                                                    ^
                                                    | (Opportunistic WAN / Satellite Uplink)
                                                    | HTTP POST /api/triage/stream
                                                    v
+------------------------+      AES-256-GCM P2P     +------------------------+
|   Field Relief Node    |<========================>|    Relief Vehicle /    |
|      (Mobile App)      |      Mesh Flooding       |   Satellite Edge Node  |
| - RAM-only 0 KB buffer |                          | - Ingress Forwarder    |
| - Offline SOS Beacon   |                          | - Gateway Relay        |
+------------------------+                          +------------------------+
```

---

## 🚀 Key Features

- **Native s390x Mainframe Acceleration**: Tested and benchmarked natively on IBM LinuxONE `s390x` architecture.
- **Zero-Storage RAM Hygiene**: Field reports and cryptographic keys reside strictly in transient RAM to protect survivor privacy and prevent data theft in hostile disaster zones.
- **End-to-End Cryptography**: Ephemeral ECDH key exchanges establish per-peer AES-256-GCM authenticated sessions.
- **Dynamic AI Triage**:
  - **Priority 1 (Critical)**: Immediate trauma, asphyxiation, building entrapment.
  - **Priority 2 (Severe)**: Rapid flooding, severe clean water shortages, structural compromise.
  - **Priority 3 (General / Moderate)**: Grid outages, blocked transit crossings.
  - **Priority 5 (Safe / Informational)**: Shelter headcounts and wellness check-ins.
- **Sub-2ms Inference**: Optimized scikit-learn and FastAPI microservice achieving >650 inferences/second/core.

---

## 📂 Repository Contents

| Path | Description |
|---|---|
| `lib/main.dart` | Complete Flutter P2P mesh client with SOS beacon bar and IBM gateway uplink |
| `triage_server.py` | Production FastAPI emergency triage engine running on IBM LinuxONE (`s390x`) |
| `emergency_triage_engine.ipynb` | Project interactive data science & triage classification notebook |
| `Predictive_AI_Hybrid_Multi_Model.ipynb` | **Prerequisite AI Lab 1**: Multi-model benchmarking (RF, GB, MLP, Calibrated Classifier) |
| `Predictive_AI_Generative_AI.ipynb` | **Prerequisite AI Lab 2**: Predictive scoring paired with generative RAG SITREP synthesis |
| `android/` | Android native project configuration (`com.example.no_internet_ibm_datathon`) |

---

## ⚡ Quick Start & Deployment

### 1. Launch Backend on IBM LinuxONE (`s390x`)
```bash
# SSH into LinuxONE
ssh -i <your_key>.pem linux1@<YOUR_SERVER_IP>

# Run triage service
python3 triage_server.py
```
- **Interactive Swagger Docs**: `http://<YOUR_SERVER_IP>:8000/docs`
- **Live Prioritized Queue**: `http://<YOUR_SERVER_IP>:8000/api/triage/queue`
- **Mainframe Architecture Telemetry**: `http://<YOUR_SERVER_IP>:8000/api/system/info`

### 2. Launch Mobile Mesh Client
```bash
flutter pub get
flutter run
```

---

## 📜 Open-Source Attributions & Dependencies (Mandatory under Rule 5)

This project is built upon open-source frameworks and libraries:

1. **[Flutter](https://flutter.dev/)** (BSD 3-Clause License)  
   Cross-platform UI framework powering the mobile mesh application.
2. **[scikit-learn](https://scikit-learn.org/)** (BSD 3-Clause License)  
   Machine learning library utilized for TF-IDF feature extraction, multi-model classification, and calibrated probability modeling on `s390x`.
3. **[FastAPI](https://fastapi.tiangolo.com/)** (MIT License)  
   High-performance asynchronous web framework providing the real-time REST ingestion API.
4. **[uvicorn](https://www.uvicorn.org/)** (BSD 3-Clause License)  
   Lightning-fast ASGI web server implementation used to run the triage engine on LinuxONE.
5. **[cryptography (Dart)](https://pub.dev/packages/cryptography)** (Apache 2.0 License)  
   Cryptographic primitives enabling in-memory ECDH key exchange and AES-256-GCM authenticated encryption.
6. **[nearby_connections](https://pub.dev/packages/nearby_connections)** (MIT License)  
   Offline peer-to-peer Wi-Fi Direct and BLE clustering engine for decentralized mesh communications.
7. **[pandas](https://pandas.pydata.org/)** & **[NumPy](https://numpy.org/)** (BSD Licenses)  
   Data wrangling, matrix manipulation, and array operations.

---

## 🏆 IBM Z Datathon 2026 Submission Evidence

- **Architecture Verification**: `uname -m` outputs `s390x`.
- **Prerequisite AI Labs**: Both `Predictive_AI_Hybrid_Multi_Model.ipynb` and `Predictive_AI_Generative_AI.ipynb` fully executed on IBM LinuxONE Jupyter Lab.
- **Live Backend Latency**: Average inference latency **1.45 ms** on IBM LinuxONE Community Cloud.
