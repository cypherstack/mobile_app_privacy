package com.cypherstack.mobile_app_privacy_example

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.concurrent.CopyOnWriteArrayList

abstract class ProbeService : AccessibilityService() {
    // Each entry starts with the event's uptime so integration tests can keep
    // events from a protection transition instead of clearing them.
    val events = CopyOnWriteArrayList<String>()
    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val text = (event.text + listOf(event.beforeText, event.contentDescription)).joinToString(" ")
        events.add("${event.eventTime} $text")
    }
    override fun onInterrupt() {}
    fun tree(): String {
        val result = StringBuilder()
        fun visit(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || depth > 50) return
            result.append(node.text).append(' ').append(node.contentDescription).append('\n')
            for (i in 0 until node.childCount) visit(node.getChild(i), depth + 1)
            node.recycle()
        }
        visit(rootInActiveWindow, 0)
        return result.toString()
    }
}
class ToolProbeService : ProbeService() {
    companion object { @Volatile var instance: ToolProbeService? = null }
    override fun onServiceConnected() { instance = this }
    override fun onDestroy() { instance = null; super.onDestroy() }
}
class NonToolProbeService : ProbeService() {
    companion object { @Volatile var instance: NonToolProbeService? = null }
    override fun onServiceConnected() { instance = this }
    override fun onDestroy() { instance = null; super.onDestroy() }
}

class FragmentProbeActivity : io.flutter.embedding.android.FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.registerExamplePlatformChannel()
    }
}

class AutoPolicyProbeActivity : android.app.Activity()
class YesPolicyProbeActivity : android.app.Activity()
class NoPolicyProbeActivity : android.app.Activity()
