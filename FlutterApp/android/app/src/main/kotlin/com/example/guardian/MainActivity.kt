package com.example.guardian

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt
import kotlin.math.abs
import android.util.Log
import java.util.LinkedList

class MainActivity: FlutterActivity(), SensorEventListener {

    private val CHANNEL = "com.guardian/sensor"
    private var methodChannel: MethodChannel? = null

    // Sensors
    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var gyroscope: Sensor? = null

    // --- TUNING THRESHOLDS ---
    // Minimum G-Force to consider a crash (Severity)
    private val IMPACT_THRESHOLD = 2.9

    // Minimum Jerk to consider a crash (Suddenness of impact)
    // Jerk = Change in G-Force between two sensor samples.
    private val JERK_THRESHOLD = 1.5

    // G-Force below this considers the phone "falling" (0G = Weightless)
    private val FREEFALL_THRESHOLD = 0.8

    // Rotation > 5 rad/s usually implies the vehicle rolling over or phone tumbling
    private val ROTATION_THRESHOLD = 5.0

    // --- DATA BUFFERS ---
    private val gForceHistory = LinkedList<Double>()
    private val rotationHistory = LinkedList<Double>()
    private val HISTORY_SIZE = 60 // Keep roughly 1-1.5 seconds of data

    private var lastUpdate: Long = 0
    private var lastGForce: Double = 1.0 // Start at 1.0 (Earth Gravity)
    private var ringtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "startAlarm") {
                startAlarm()
                result.success(null)
            } else if (call.method == "stopAlarm") {
                stopAlarm()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

        // SENSOR_DELAY_GAME provides data ~50Hz (every 20ms), good for crash detection
        accelerometer?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
        gyroscope?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        // 1. HANDLE ACCELEROMETER (Impact & Jerk)
        if (event?.sensor?.type == Sensor.TYPE_ACCELEROMETER) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]

            // Calculate Absolute G-Force (Divided by 9.8 to normalize to Gs)
            val currentGForce = sqrt((x/9.8)*(x/9.8) + (y/9.8)*(y/9.8) + (z/9.8)*(z/9.8))

            // Calculate Jerk: The absolute change from the last reading
            val jerk = abs(currentGForce - lastGForce)

            // Update history and last reading
            addToHistory(gForceHistory, currentGForce)
            lastGForce = currentGForce

            // LOGIC: High Impact AND Sudden Change (Jerk)
            if (currentGForce > IMPACT_THRESHOLD && jerk > JERK_THRESHOLD) {
                checkForCrash(currentGForce, jerk)
            }
        }

        // 2. HANDLE GYROSCOPE (Rotation/Tumble)
        if (event?.sensor?.type == Sensor.TYPE_GYROSCOPE) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]

            val totalRotation = sqrt(x*x + y*y + z*z)
            addToHistory(rotationHistory, totalRotation.toDouble())
        }
    }

    private fun checkForCrash(gForce: Double, jerk: Double) {
        val curTime = System.currentTimeMillis()
        // Prevent spamming alerts (wait 3 seconds between triggers)
        if ((curTime - lastUpdate) > 3000) {

            // FILTER 1: PHONE DROP DETECTION
            // A phone drop is usually preceded by a moment of "weightlessness" (Freefall)
            if (wasFreefallDetected()) {
                Log.d("GUARDIAN_AI", "IGNORED: Phone Drop Detected (Freefall pre-impact)")
                return
            }

            // FILTER 2: ROLLOVER DETECTION
            // If the phone is spinning violently, it might be a rollover or bike crash
            val isRollover = wasHighRotationDetected()
            val crashType = if (isRollover) "ROLLOVER/BIKE CRASH" else "FRONTAL/SIDE IMPACT"

            lastUpdate = curTime
            Log.d("GUARDIAN_AI", "🚨 CRASH CONFIRMED: $crashType | Force: $gForce G | Jerk: $jerk")

            // Send the G-Force to Flutter
            runOnUiThread {
                methodChannel?.invokeMethod("crashDetected", gForce)
            }
        }
    }

    private fun addToHistory(list: LinkedList<Double>, value: Double) {
        if (list.size >= HISTORY_SIZE) list.removeFirst()
        list.add(value)
    }

    // Check if the phone was in freefall (near 0G) in the last second
    private fun wasFreefallDetected(): Boolean {
        // If we find G-Force < 0.8 in the recent history, assume it was falling
        for (g in gForceHistory) {
            if (g < FREEFALL_THRESHOLD) return true
        }
        return false
    }

    private fun wasHighRotationDetected(): Boolean {
        for (r in rotationHistory) {
            if (r > ROTATION_THRESHOLD) return true
        }
        return false
    }

    // --- ALARM HELPERS ---
    private fun startAlarm() {
        try {
            val notificationUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ringtone = RingtoneManager.getRingtone(applicationContext, notificationUri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                ringtone?.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            ringtone?.play()
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun stopAlarm() {
        try {
            ringtone?.stop()
        } catch (e: Exception) { e.printStackTrace() }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(this)
    }
}