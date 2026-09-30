package com.stanchion.guard_app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * The gate. Native, full-screen, over the lock screen, built in code so it
 * needs no resources and starts in a few milliseconds. Same words and actions
 * as the design (docs/redesign/grok-final/phone/gate-red.png): countdown,
 * what and when, "We never touch your trades", Stay out, Hold to look only
 * (three seconds). Block hides the second.
 * Colours follow app/lib/theme/tokens.dart.
 */
class GateActivity : Activity() {

    private lateinit var store: GateStore
    private var window: GateWindow? = null
    private var timer: CountDownTimer? = null
    private val holdHandler = Handler(Looper.getMainLooper())
    private var holdRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = GateStore(this)
        window = intent.getStringExtra(GateService.EXTRA_WINDOW_ID)?.let { store.window(it) }
        val w = window ?: return finish()

        showOverLockScreen()

        val dp = resources.displayMetrics.density
        val hard = store.protection == "hard-block"
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            // docs/redesign/grok-final/phone/gate-red.png: ink ground, red tint at the top.
            background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(RED_TINT, INK_BG, INK_BG))
            setPadding((24 * dp).toInt(), (48 * dp).toInt(), (24 * dp).toInt(), (32 * dp).toInt())
        }

        val label = text(if (hard) "BLOCK IS ON" else "COVER IS ON", 12f, RED, Typeface.BOLD).apply { letterSpacing = 0.14f }
        val countdown = text("--:--", 72f, RED, Typeface.BOLD).apply { gravity = Gravity.CENTER_HORIZONTAL }
        val until = text("until you can trade again", 14f, INK_MUTED, Typeface.NORMAL).apply { gravity = Gravity.CENTER_HORIZONTAL }
        val what = text(w.events.ifBlank { "High impact news" }, 22f, INK_TEXT, Typeface.BOLD)
        val whenLine = text("Today · " + hhmm(w.opensAtMs) + " to " + hhmm(w.closesAtMs), 16f, SKY, Typeface.NORMAL)
        val mode = text(if (hard) "Block · no look" else "Cover · look ok", 14f, SKY, Typeface.NORMAL)
        val promise = text(
            if (hard) "We never touch your trades. Trading now may break your firm's rules."
            else "We never touch your trades. Looking is fine. Trading now may break your firm's rules.",
            14f, INK_MUTED, Typeface.NORMAL,
        ).apply { gravity = Gravity.CENTER_HORIZONTAL }

        val stayOut = button("Stay out", RED, Color.WHITE, 0).apply {
            setOnClickListener { stayOut(w) }
        }
        val holdView = button("Hold to look only", INK_SURFACE, INK_TEXT, SKY_LINE).apply {
            setOnTouchListener { v, e -> onHold(v, e, w) }
            visibility = if (hard) View.GONE else View.VISIBLE
        }

        root.addView(label, wrap(dp, 20))
        listOf(countdown, until).forEach { root.addView(it, wrap(dp, 4)) }
        root.addView(View(this), LinearLayout.LayoutParams(0, (28 * dp).toInt()))
        listOf(what, whenLine, mode).forEach { root.addView(it, wrap(dp, 6)) }
        root.addView(View(this), LinearLayout.LayoutParams(0, 0, 1f))
        root.addView(promise, wrap(dp, 16))
        root.addView(stayOut, button(dp))
        root.addView(holdView, button(dp))
        setContentView(root)

        timer = object : CountDownTimer(w.closesAtMs - System.currentTimeMillis(), 1000) {
            override fun onTick(ms: Long) {
                val s = ms / 1000
                countdown.text = String.format("%02d:%02d", s / 60, s % 60)
            }
            override fun onFinish() {
                store.appendJournal(w.windowId, "stayed-out", System.currentTimeMillis())
                finish()
            }
        }.start()
    }

    private fun stayOut(w: GateWindow) {
        store.appendJournal(w.windowId, "stayed-out", System.currentTimeMillis())
        // Take the trading app off the screen too, not just the gate.
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        finish()
    }

    private fun onHold(v: View, e: MotionEvent, w: GateWindow): Boolean {
        when (e.action) {
            MotionEvent.ACTION_DOWN -> {
                (v as Button).text = "Keep holding…"
                holdRunnable = Runnable {
                    store.viewingUntilMs = System.currentTimeMillis() + 60_000L
                    store.appendJournal(w.windowId, "viewed", System.currentTimeMillis())
                    finish()
                }.also { holdHandler.postDelayed(it, 3000) }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                (v as Button).text = "Hold to look only"
                holdRunnable?.let { holdHandler.removeCallbacks(it) }
            }
        }
        return true
    }

    override fun onBackPressed() {
        // The gate doesn't dismiss with Back. Stay out or hold to view.
    }

    override fun onDestroy() {
        timer?.cancel()
        holdRunnable?.let { holdHandler.removeCallbacks(it) }
        super.onDestroy()
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            (getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun text(s: String, sp: Float, color: Int, style: Int) = TextView(this).apply {
        text = s
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        setTextColor(color)
        setTypeface(Typeface.SANS_SERIF, style)
    }

    private fun button(s: String, bg: Int, fg: Int, line: Int) = Button(this).apply {
        text = s
        isAllCaps = false
        stateListAnimator = null
        background = GradientDrawable().apply {
            setColor(bg)
            cornerRadius = 8 * resources.displayMetrics.density
            if (line != 0) setStroke((1 * resources.displayMetrics.density).toInt(), line)
        }
        setTextColor(fg)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
        setTypeface(Typeface.SANS_SERIF, Typeface.BOLD)
    }

    private fun wrap(dp: Float, bottomDp: Int) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT,
    ).apply { bottomMargin = (bottomDp * dp).toInt() }

    private fun button(dp: Float) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, (56 * dp).toInt(),
    ).apply { topMargin = (10 * dp).toInt() }


    companion object {
        fun hhmm(ms: Long): String {
            val c = java.util.Calendar.getInstance(java.util.TimeZone.getDefault()).apply { timeInMillis = ms }
            return String.format("%d:%02d", c.get(java.util.Calendar.HOUR_OF_DAY), c.get(java.util.Calendar.MINUTE))
        }

        // app/lib/theme/tokens.dart (Grok pack): ink, sky, red.
        private const val INK_BG = 0xFF070D18.toInt()
        private const val INK_SURFACE = 0xFF0C1422.toInt()
        private const val INK_TEXT = 0xFFEDF2F8.toInt()
        private const val INK_MUTED = 0xFF8B9AAE.toInt()
        private const val SKY = 0xFF5BC8F5.toInt()
        private const val SKY_LINE = 0x595BC8F5
        private const val RED = 0xFFE5484D.toInt()
        private const val RED_TINT = 0xFF2A0F16.toInt()

        /**
         * From a service this is a background activity launch. Android 10+ allows
         * it when "display over other apps" is granted; otherwise the honest route
         * is a full-screen-intent notification, which the OS turns into the
         * activity on a locked or idle screen and a heads-up otherwise.
         */
        fun show(context: Context, windowId: String) {
            val intent = Intent(context, GateActivity::class.java)
                .putExtra(GateService.EXTRA_WINDOW_ID, windowId)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (android.provider.Settings.canDrawOverlays(context)) {
                context.startActivity(intent)
                return
            }
            val w = GateStore(context).window(windowId) ?: return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                nm.createNotificationChannel(android.app.NotificationChannel("ladder_urgent", "Window opening", android.app.NotificationManager.IMPORTANCE_HIGH))
            }
            val pi = android.app.PendingIntent.getActivity(
                context, 2, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
            )
            nm.notify(4102, androidx.core.app.NotificationCompat.Builder(context, "ladder_urgent")
                .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                .setContentTitle("Cover is on")
                .setContentText(w.events.ifBlank { "High impact news" } + ". Stay out until " + hhmm(w.closesAtMs) + ".")
                .setPriority(androidx.core.app.NotificationCompat.PRIORITY_MAX)
                .setCategory(androidx.core.app.NotificationCompat.CATEGORY_ALARM)
                .setFullScreenIntent(pi, true)
                .setContentIntent(pi)
                .setAutoCancel(true)
                .build())
        }
    }
}
