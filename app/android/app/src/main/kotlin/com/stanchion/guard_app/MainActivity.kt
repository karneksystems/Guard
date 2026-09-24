package com.stanchion.guard_app

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Two small channels the Dart side talks to. Detection and the overlay itself
 * (GateService) land in M4; this is the permissions and app-list half of M2.
 *
 * No QUERY_ALL_PACKAGES: the manifest declares <queries> for the handful of
 * trading apps we can gate, which is what Play wants.
 */
class MainActivity : FlutterActivity() {

    private val gateable = listOf(
        "net.metaquotes.metatrader5" to "MetaTrader 5",
        "net.metaquotes.metatrader4" to "MetaTrader 4",
        "com.spotware.ct" to "cTrader",
        "com.tradingview.tradingviewapp" to "TradingView",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "guard/gate").setMethodCallHandler { call, result ->
            when (call.method) {
                "listApps" -> result.success(gateable.map { (id, label) ->
                    mapOf("id" to id, "label" to label, "installed" to isInstalled(id))
                })
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "guard/permissions").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status())
                "request" -> {
                    val name = call.argument<String>("name")
                    if (name == null) result.error("bad-args", "name required", null)
                    else { request(name); result.success(null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0); true
    } catch (e: PackageManager.NameNotFoundException) { false }

    private fun status(): Map<String, Boolean> {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        }

        return mapOf(
            "notifications" to nm.areNotificationsEnabled(),
            "usageStats" to (mode == AppOpsManager.MODE_ALLOWED),
            "overlay" to Settings.canDrawOverlays(this),
            "exactAlarm" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()),
            "fullScreenIntent" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE || nm.canUseFullScreenIntent()),
            "batteryUnrestricted" to pm.isIgnoringBatteryOptimizations(packageName),
        )
    }

    private fun request(name: String) {
        val pkgUri = Uri.parse("package:$packageName")
        val intent = when (name) {
            "notifications" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            "usageStats" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            "overlay" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pkgUri)
            "exactAlarm" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkgUri) else null
            "fullScreenIntent" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkgUri) else null
            // Play restricts the direct battery-exemption prompt; the settings page is allowed.
            "batteryUnrestricted" -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            else -> null
        } ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try { startActivity(intent) } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}
