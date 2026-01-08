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
import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.core.app.NotificationCompat
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
    
    // Thresholds
    private val IMPACT_THRESHOLD = 2.5 
    private val FREEFALL_THRESHOLD = 0.5 
    private val ROTATION_THRESHOLD = 4.0 // >4 rad/s means the car/bike is flipping
    
    // History Buffers
    private val gForceHistory = LinkedList<Double>()
    private val rotationHistory = LinkedList<Double>()
    private val HISTORY_SIZE = 50 
    
    private var lastUpdate: Long = 0
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
        
        accelerometer?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
        gyroscope?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        // 1. HANDLE ACCELEROMETER (Impact)
        if (event?.sensor?.type == Sensor.TYPE_ACCELEROMETER) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]
            
            val gForce = sqrt((x/9.8)*(x/9.8) + (y/9.8)*(y/9.8) + (z/9.8)*(z/9.8))
            addToHistory(gForceHistory, gForce)

            if (gForce > IMPACT_THRESHOLD) {
                checkForCrash(gForce)
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

    private fun checkForCrash(gForce: Double) {
        val curTime = System.currentTimeMillis()
        if ((curTime - lastUpdate) > 3000) {
            
            // Filter 1: Was it a phone drop? (Freefall check)
            if (wasFreefallDetected()) {
                Log.d("GUARDIAN_AI", "Ignored: Phone Drop Detected")
                return
            }

            // Filter 2: Check for Rotation (Bike/Rollover)
            val isRollover = wasHighRotationDetected()
            val crashType = if (isRollover) "ROLLOVER/BIKE CRASH" else "FRONTAL IMPACT"

            lastUpdate = curTime
            Log.d("GUARDIAN_AI", "CRASH CONFIRMED: $crashType ($gForce G)")
            
            // Send the G-Force to Flutter (We can also send the 'Type' later if we want)
            runOnUiThread {
                methodChannel?.invokeMethod("crashDetected", gForce)
            }
        }
    }

    private fun addToHistory(list: LinkedList<Double>, value: Double) {
        if (list.size >= HISTORY_SIZE) list.removeFirst()
        list.add(value)
    }

    private fun wasFreefallDetected(): Boolean {
        for (g in gForceHistory) {
            if (g < FREEFALL_THRESHOLD) return true
        }
        return false
    }

    // New: Check if we were spinning violently in the last second
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