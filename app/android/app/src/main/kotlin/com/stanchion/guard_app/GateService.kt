package com.stanchion.guard_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Runs only while a window is open. Polls usage events once a second; when a
 * gated package comes to the front, shows GateActivity unless the user chose
 * "view for 60 seconds" or protection is warn-only. Stops itself at closes_at.
 */
class GateService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var store: GateStore
    private var window: GateWindow? = null
    private var lastPoll = 0L
    private var lastShown = 0L

    /** True while the gate can act; the edge into it checks who is in front right now. */
    private var armed = false

    private val tick = object : Runnable {
        override fun run() {
            val w = window ?: return stopSelf()
            val now = System.currentTimeMillis()
            if (now >= w.closesAtMs) return stopSelf()
            val canAct = now >= w.opensAtMs && store.protection != "warn-only" && now >= store.viewingUntilMs
            if (canAct) {
                // The trader may already be sitting in MT5 when the window opens, or when
                // their sixty seconds of viewing run out: check the current foreground on
                // the way in, then watch for changes.
                val hit = if (!armed) foregroundPackage(now) in store.gatedPackages else gatedAppCameToFront(lastPoll, now)
                if (hit && now - lastShown > 1500) {
                    lastShown = now
                    GateActivity.show(this@GateService, w.windowId)
                }
            }
            armed = canAct
            lastPoll = now
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        store = GateStore(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getStringExtra(EXTRA_WINDOW_ID)
        window = id?.let { store.window(it) }
        val w = window
        // A started service must call startForeground even if it stops at once,
        // and on 12+ the call itself can be refused when we were started from the
        // background (a redelivered intent after the process died). Either way,
        // stop cleanly; the app re-arms from the foreground.
        try {
            startInForeground(w ?: GateWindow("none", 0, 0, "", ""))
        } catch (e: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (w == null || System.currentTimeMillis() >= w.closesAtMs) {
            stopSelf()
            return START_NOT_STICKY
        }
        armed = false
        lastPoll = System.currentTimeMillis() - 2000
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_REDELIVER_INTENT
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun gatedAppCameToFront(from: Long, to: Long): Boolean {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val gated = store.gatedPackages
        val events = usm.queryEvents(from - 1000, to)
        val e = UsageEvents.Event()
        var hit = false
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val foreground = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                e.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            else
                @Suppress("DEPRECATION") e.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            if (foreground && e.packageName in gated) hit = true
            if (foreground && e.packageName == packageName) hit = false
        }
        return hit
    }

    /** The package most recently brought to the front, looking back two minutes. */
    private fun foregroundPackage(now: Long): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(now - 120_000, now)
        val e = UsageEvents.Event()
        var last: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val foreground = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                e.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            else
                @Suppress("DEPRECATION") e.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            if (foreground) last = e.packageName
        }
        return last
    }

    private fun startInForeground(w: GateWindow) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Guard is watching", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Shown only while a restricted window is open."
                }
            )
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle("Restricted window open: ${w.instrument}")
            .setContentText("Watching for your trading app until the window ends.")
            .setOngoing(true)
            .setContentIntent(open)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
    }

    companion object {
        const val EXTRA_WINDOW_ID = "windowId"
        private const val CHANNEL = "gate_service"
        private const val NOTIFICATION_ID = 4100

        fun start(context: Context, windowId: String) {
            val intent = Intent(context, GateService::class.java).putExtra(EXTRA_WINDOW_ID, windowId)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent)
            else context.startService(intent)
        }
    }
}
