# 🛡️ Guardian: AI-Powered Accident Detection & Emergency Response System

> **"Seconds Save Lives."**
> 
> Guardian is a Flutter-based intelligent safety application designed to detect vehicular crashes in real-time, analyze severity with AI, and bridge the gap between victims, emergency contacts, and hospitals.

---

## 🌟 Key Features

* **⚡ Smart Crash & Rollover Detection:** * Uses native Android sensors (Accelerometer & Gyroscope) to detect impacts.
    * **Advanced Filtering:** Distinguishes between **Car Crashes**, **Bike Rollovers** (>4 rad/s rotation), and accidental **Phone Drops** (freefall detection) to prevent false alarms.
* **🎙️ Audio Evidence "Black Box":** Automatically records ambient audio for 10 seconds during the alert countdown. This audio is uploaded to the cloud to help responders verify the severity of the crash.
* **🧠 Gemini AI Analysis:** Uses Generative AI (via Pollinations) to process sensor data and categorize the incident as "CRITICAL" (Ambulance needed) or "WARNING".
* **🏥 Hospital Dispatch Dashboard:** A dedicated interface for hospitals to receive alerts, view the crash location on a map, listen to the audio evidence, and **"Accept"** the emergency.
* **📍 Instant SOS with Geolocation:** Automatically fetches high-accuracy GPS coordinates and sends an SMS with a tracking link to emergency contacts.
* **☁️ Real-Time Status Updates:** When a hospital accepts the emergency, the user's screen instantly updates from "Waiting for Help" to **"Ambulance Dispatched"** via Firebase streams.

---

## 📸 Screenshots

| **Emergency Alert** | **Hospital Dashboard** | **Home Screen** |
|:---:|:---:|:---:|
| ![Emergency Screen](screenshots/emergency_screen.png) | ![Hospital Dashboard](screenshots/hospital_dashboard.png) | ![Home Screen](screenshots/home_screen.png) |
| *Real-time Countdown & SOS* | *Incoming Alerts & Map View* | *Protection Status & Contacts* |


---

## 🛠️ Tech Stack

* **Framework:** Flutter (Dart)
* **Native Layer:** Kotlin (MethodChannels for background sensor processing)
* **Backend:** Firebase Firestore (Real-time database)
* **Auth:** Firebase Auth & Google Sign-In
* **AI Service:** Pollinations.ai API (Prompt Engineering for Crash Analysis)
* **Hardware Features:**
    * `sensors_plus` & Native Android SensorManager
    * `record` & `audioplayers` (Audio Evidence)
    * `geolocator` (GPS)
    * `sms_sender_background` (Emergency Alerts)

---

## ⚙️ How It Works (Workflow)

1.  **Monitoring:** The app listens to sensor streams in the background (using a low-latency native channel).
2.  **Detection:**
    * **Impact:** >2.5G force detected.
    * **Rollover:** High rotation detected (useful for bike accidents).
    * **Filter:** If "Freefall" is detected beforehand, the alert is ignored (Phone Drop).
3.  **Alert Phase:**
    * A loud alarm sounds.
    * **Microphone starts recording**.
    * A 10-second countdown gives the driver a chance to cancel ("I Am Safe").
4.  **Action (If not cancelled):**
    * **Data Upload:** G-Force, Location, and **Base64 encoded Audio** are sent to Firestore.
    * **SMS Dispatch:** Emergency contacts receive a text with the location link.
    * **Hospital Alert:** The incident appears on the **Hospital Dashboard**.
5.  **Response:**
    * Paramedics listen to the audio evidence and view the map.
    * Hospital clicks **"Accept Emergency"**.
    * User's app turns **Green**: "AMBULANCE DISPATCHED".

---

## 📥 Installation

1.  **Prerequisites:** Flutter SDK, Android Studio, and a physical Android device (Simulators cannot test G-Force sensors).
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
    * Enable **Authentication** (Google) and **Firestore** in the Firebase Console.
5.  **Run the App:**
    ```bash
    flutter run
    ```

---

## ⚠️ Disclaimer
*Guardian is a safety aid and prototype. It relies on network availability for SMS/Cloud features and sensor accuracy for detection. It should not replace responsible driving.*
