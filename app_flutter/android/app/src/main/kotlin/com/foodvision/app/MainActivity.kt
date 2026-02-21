package com.foodvision.app

import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.sharedpreferences.SharedPreferencesPlugin
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: io.flutter.embedding.android.FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
