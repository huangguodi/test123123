package com.example.address

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.os.Build
import java.security.MessageDigest

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.address/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAppSignature") {
                try {
                    val signature = getAppSignature()
                    result.success(signature)
                } catch (e: Exception) {
                    result.error("SIG_ERR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getAppSignature(): String {
        val packageName = context.packageName
        val packageManager = context.packageManager
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val packageInfo = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            val signingInfo = packageInfo.signingInfo
            if (signingInfo == null) {
                null
            } else {
                if (signingInfo.hasMultipleSigners()) {
                    signingInfo.apkContentsSigners
                } else {
                    signingInfo.signingCertificateHistory
                }
            }
        } else {
            @Suppress("DEPRECATION")
            val packageInfo = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            @Suppress("DEPRECATION")
            packageInfo.signatures
        }

        if (signatures == null || signatures.isEmpty()) {
            throw Exception("No signatures found")
        }

        val signature = signatures[0]
        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest(signature.toByteArray())
        return digest.joinToString(":") { "%02X".format(it) }
    }
}
