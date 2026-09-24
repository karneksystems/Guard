package com.stanchion.guard_app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * The windows the gate must enforce, the packages to gate, the protection mode,
 * and outcomes waiting to go back to the app. SharedPreferences because it has
 * to be readable from a receiver at boot with nothing else running.
 * Nothing here ever leaves the device except the journal outcome, which the app
 * posts without the package name.
 */
data class GateWindow(
    val windowId: String,
    val opensAtMs: Long,
    val closesAtMs: Long,
    val instrument: String,
    val events: String,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("windowId", windowId).put("opensAtMs", opensAtMs).put("closesAtMs", closesAtMs)
        .put("instrument", instrument).put("events", events)

    companion object {
        fun fromJson(o: JSONObject) = GateWindow(
            o.getString("windowId"), o.getLong("opensAtMs"), o.getLong("closesAtMs"),
            o.getString("instrument"), o.optString("events", ""),
        )
    }
}

class GateStore(context: Context) {
    private val prefs = context.getSharedPreferences("guard.gate", Context.MODE_PRIVATE)

    var windows: List<GateWindow>
        get() = runCatching {
            val arr = JSONArray(prefs.getString("windows", "[]"))
            (0 until arr.length()).map { GateWindow.fromJson(arr.getJSONObject(it)) }
        }.getOrDefault(emptyList())
        set(value) {
            prefs.edit().putString("windows", JSONArray(value.map { it.toJson() }).toString()).apply()
        }

    var gatedPackages: Set<String>
        get() = prefs.getStringSet("gated", setOf("net.metaquotes.metatrader5")) ?: emptySet()
        set(value) { prefs.edit().putStringSet("gated", value).apply() }

    /** warn-only, soft-gate, hard-block */
    var protection: String
        get() = prefs.getString("protection", "soft-gate") ?: "soft-gate"
        set(value) { prefs.edit().putString("protection", value).apply() }

    /** "View for 60 seconds": the gate stays down until this instant. */
    var viewingUntilMs: Long
        get() = prefs.getLong("viewingUntil", 0L)
        set(value) { prefs.edit().putLong("viewingUntil", value).apply() }

    fun window(windowId: String): GateWindow? = windows.firstOrNull { it.windowId == windowId }

    fun appendJournal(windowId: String, outcome: String, atMs: Long) {
        val arr = JSONArray(prefs.getString("journal", "[]"))
        arr.put(JSONObject().put("windowId", windowId).put("outcome", outcome).put("atMs", atMs))
        prefs.edit().putString("journal", arr.toString()).apply()
    }

    /** Returns and clears the pending outcomes. */
    fun drainJournal(): List<Map<String, Any>> {
        val arr = JSONArray(prefs.getString("journal", "[]"))
        prefs.edit().remove("journal").apply()
        return (0 until arr.length()).map {
            val o = arr.getJSONObject(it)
            mapOf("windowId" to o.getString("windowId"), "outcome" to o.getString("outcome"), "atMs" to o.getLong("atMs"))
        }
    }
}
