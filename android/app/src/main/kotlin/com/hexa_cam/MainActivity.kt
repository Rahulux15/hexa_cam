package com.hexa_cam

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15+ (SDK 35): draw behind system bars; Flutter applies safe padding.
        // Prefer Activity 1.8+ enableEdgeToEdge when this Activity is a ComponentActivity;
        // otherwise WindowCompat (works on all Activity subclasses Flutter uses).
        when (this) {
            is ComponentActivity -> enableEdgeToEdge()
            else -> WindowCompat.setDecorFitsSystemWindows(window, false)
        }
        super.onCreate(savedInstanceState)
    }
}
