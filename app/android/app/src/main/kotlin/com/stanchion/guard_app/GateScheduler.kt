package com.stanchion.guard_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * One exact alarm per window at opens_at, which starts GateService. No always-on
 * service (decision D6). If exact alarms are denied, the alarm is a window
 * starting ten minutes early and the service idles until opens_at.
 */
object GateScheduler {
    private const val REQUEST_BASE = 41000

    fun reschedule(context: Context, store: GateStore = GateStore(context)) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()

        store.windows.forEachIndexed { i, w ->
            val pi = pending(context, i, w.windowId)
            am.cancel(pi)
            if (w.closesAtMs <= now) return@forEachIndexed
            val at = w.opensAtMs
            if (at <= now) {
                // Already inside the window: start straight away.
                GateService.start(context, w.windowId)
                return@forEachIndexed
            }
            if (exact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.setWindow(AlarmManager.RTC_WAKEUP, at - 10 * 60_000L, 10 * 60_000L, pi)
            }
        }
    }

    fun cancelAll(context: Context, count: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0 until maxOf(count, 40)) am.cancel(pending(context, i, ""))
    }

    private fun pending(context: Context, index: Int, windowId: String): PendingIntent {
        val intent = Intent(context, GateAlarmReceiver::class.java).putExtra(GateService.EXTRA_WINDOW_ID, windowId)
        return PendingIntent.getBroadcast(
            context, REQUEST_BASE + index, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
