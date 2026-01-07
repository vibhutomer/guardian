# 🛡️ Guardian: AI-Powered Accident Detection & Emergency Response System

> **"Seconds Save Lives."**
> 
> Guardian is a Flutter-based intelligent safety application designed to detect vehicular crashes in real-time using device sensors, analyze severity with Gemini AI, and instantly dispatch automated SOS alerts with precise location data to emergency contacts and services.

---


## 🌟 Key Features

* **⚡ Real-Time G-Force Monitoring:** Utilizes the device's accelerometer and gyroscope via a native channel (`com.guardian/sensor`) to continuously monitor driving forces.
* **💥 Automated Crash Detection:** Triggers an emergency sequence instantly when G-forces exceed the safety threshold (simulated at >2.5G for testing).
* **🧠 Gemini AI Crash Analysis:** Uses **Generative AI** (via Pollinations/Gemini) to analyze the G-force data and categorize the crash as "CRITICAL" (Ambulance needed) or "WARNING" (Alert contacts).
* **📍 Instant SOS with Geolocation:** Automatically fetches high-accuracy GPS coordinates and sends an SMS with a clickable **Google Maps link** to emergency contacts.
* **⏳ 10-Second Fail-Safe Countdown:** Provides a 10-second buffer with a loud audible alarm for the driver to cancel the alert in case of a false positive ("I Am Safe").
* **☁️ Cloud Reporting:** Automatically uploads accident data (G-force, time, AI analysis, location) to **Firebase Firestore** for record-keeping and insurance/legal verification.
* **🔒 Secure Authentication:** Google Sign-In and Firebase Auth integration for secure user management.

---

## 🛠️ Tech Stack

* **Framework:** Flutter (Dart)
* **Backend & Auth:** Firebase (Core, Auth, Firestore)
* **Artificial Intelligence:** Gemini AI (via Pollinations API)
* **Native Integration:** Kotlin/Swift Method Channels (`com.guardian/sensor`) for background sensor access.
* **Location Services:** `geolocator` package for high-precision GPS.
* **Communication:** `sms_sender_background` for direct SMS dispatch.

---

## ⚙️ How It Works (Workflow)

1.  **Monitoring:** Once the user logs in and grants permissions (Location, SMS), the app enters "Safe Mode", listening to sensor streams in the background.
2.  **Detection:** If a sudden deceleration (crash) is detected by the native layer, it sends a signal to the Flutter engine.
3.  **Alert Phase:**
    * The app triggers the **Emergency Screen**.
    * A loud alarm starts playing.
    * A 10-second countdown begins.
4.  **Action (If not cancelled):**
    * **GPS Lock:** Captures current latitude/longitude.
    * **AI Diagnostics:** Sends G-force data to Gemini AI. The AI decides:
        * *High G-Force (>4.0):* "CRITICAL: Calling nearest hospital..."
        * *Lower G-Force:* "WARNING: Alerting contacts..."
    * **SMS Dispatch:** Sends text messages to stored contacts: *"SOS! Crash detected! Help needed. Track me: [Google Maps Link]"*
    * **Data Logging:** Saves the incident report to the database.

---

## 🚀 Future Impact & Roadmap

Guardian is not just an app; it is a prototype for the future of **Smart Traffic Safety infrastructure**.

### 1. 🏥 Integration with Emergency Services (E911)
* **Current:** Alerts personal contacts.
* **Future:** Direct API integration with local Emergency Response Centers (911/112) to dispatch paramedics automatically without human intervention, sharing the victim's blood type and medical history securely.

### 2. 🏙️ Smart City & IoT Connectivity
* **V2X Communication:** The app could communicate with "Smart Traffic Lights" to turn signals red for oncoming traffic, preventing secondary pile-ups at the crash site.
* **Black Box Telematics:** Serving as a digital "Black Box" for insurance companies to speed up claims processing and accident reconstruction using the recorded G-force and GPS logs.

### 3. 🚗 Predictive Safety
* **Driver Behavior Analysis:** Using the AI to analyze long-term driving patterns and warn drivers of "fatigue" or "reckless driving" *before* an accident occurs.
* **Route Risk Assessment:** Warning users when entering "High Accident Zones" based on historical crash data aggregated from all Guardian users.

---

## 📥 Installation

1.  **Prerequisites:** Flutter SDK installed, Android Studio/VS Code, and a physical device (simulators cannot accurately simulate G-force sensors).
2.  **Clone the Repository:**
    ```bash
    git clone [https://github.com/vibhutomer/guardian.git](https://github.com/vibhutomer/guardian.git)
    cd guardian
    ```
3.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Firebase Setup:**
    * Add your `google-services.json` to `android/app/`.
    * Enable Authentication (Google) and Firestore in your Firebase Console.
5.  **Run the App:**
    ```bash
    flutter run
    ```

---

## ⚠️ Disclaimer
*Guardian is a safety aid and should not replace responsible driving. The effectiveness of GPS and SMS depends on network availability.*
