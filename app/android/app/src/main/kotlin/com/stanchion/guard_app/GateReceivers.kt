package com.stanchion.guard_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** The window's alarm fired: start watching. */
class GateAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(GateService.EXTRA_WINDOW_ID) ?: return
        GateService.start(context, id)
    }
}

/** Alarms don't survive a reboot; the stored windows do. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            GateScheduler.reschedule(context)
        }
    }
}
