package com.stanchion.guard_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * The window's alarm fired: start watching. An exact alarm is exempt from the
 * Android 12+ ban on starting a foreground service from the background; an
 * inexact fallback alarm is not, and the start throws. Then the best we can do
 * is a loud notification that brings the user into the app, where the schedule
 * re-arms from the foreground.
 */
class GateAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(GateService.EXTRA_WINDOW_ID) ?: return
        try {
            GateService.start(context, id)
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException on 12+, or anything else.
            notifyCannotWatch(context, id)
        }
    }

    private fun notifyCannotWatch(context: Context, windowId: String) {
        val w = GateStore(context).window(windowId) ?: return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Window opening", NotificationManager.IMPORTANCE_HIGH))
        }
        val open = PendingIntent.getActivity(
            context, 1, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        nm.notify(NOTIFICATION_ID, NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle("Restricted: ${w.instrument}")
            .setContentText("Open the app to arm the gate. Allow exact alarms in Settings so this is automatic.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build())
    }

    private companion object {
        const val CHANNEL = "ladder_urgent"
        const val NOTIFICATION_ID = 4101
    }
}

/**
 * Alarms don't survive a reboot; the stored windows do. The same applies when
 * the user flips the exact-alarm permission, which cancels every exact alarm.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val rearm = intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && intent.action == AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED)
        if (rearm) {
            try {
                GateScheduler.reschedule(context)
            } catch (e: Exception) {
                // A window already open cannot start its service from here on 12+; the app arms it on next open.
            }
        }
    }
}
