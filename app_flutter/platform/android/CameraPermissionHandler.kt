/// Platform-specific camera permission handler for Android
/// This file is a placeholder for native Kotlin code that manages camera permissions on Android.
///
/// In a real implementation, this would be part of the Android runner project
/// and integrate with Kotlin code to request and check camera permissions.
///
/// Key permissions needed on Android (declared in AndroidManifest.xml):
/// - android.permission.CAMERA
/// - android.permission.READ_EXTERNAL_STORAGE
/// - android.permission.WRITE_EXTERNAL_STORAGE
/// - android.permission.INTERNET
///
/// Runtime permissions (Android 6.0+) must be requested via ActivityCompat.
///
/// TODO: If custom native Android code is needed, create Kotlin files in android/app/src/main/kotlin/

package com.foodvision.app

import android.Manifest
import android.content.Context
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class CameraPermissionHandler(private val context: Context) {
    fun requestCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    fun requestStoragePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_EXTERNAL_STORAGE
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }
}
