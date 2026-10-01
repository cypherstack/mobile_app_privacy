package com.cypherstack.mobile_app_privacy_example

import android.app.Activity
import android.app.UiAutomation
import android.content.Intent
import android.os.Build
import android.os.ParcelFileDescriptor
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class AccessibilityPrivacyTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val automation = instrumentation.getUiAutomation(
        UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES
    )
    private var previousServices: String? = null
    private var previousEnabled: String? = null

    private fun shell(command: String): String =
        ParcelFileDescriptor.AutoCloseInputStream(automation.executeShellCommand(command))
            .bufferedReader().use { it.readText().trim() }

    @Before fun enableServices() {
        previousServices = shell("settings get secure enabled_accessibility_services")
        previousEnabled = shell("settings get secure accessibility_enabled")
        val pkg = context.packageName
        val services = listOfNotNull(previousServices?.takeUnless { it == "null" || it.isEmpty() },
            "$pkg/.ToolProbeService", "$pkg/.NonToolProbeService").joinToString(":")
        shell("settings put secure enabled_accessibility_services $services")
        shell("settings put secure accessibility_enabled 1")
        await("probe services connected") {
            ToolProbeService.instance != null && NonToolProbeService.instance != null
        }
        ToolProbeService.instance!!.events.clear()
        NonToolProbeService.instance!!.events.clear()
    }

    @After fun restoreServices() {
        for ((key, value) in listOf("enabled_accessibility_services" to previousServices,
            "accessibility_enabled" to previousEnabled)) {
            if (value == null) continue
            shell(if (value == "null" || value.isEmpty()) "settings delete secure $key"
                  else "settings put secure $key $value")
        }
    }

    @Test fun flutterActivity() = checkHost(MainActivity::class.java)
    @Test fun flutterFragmentActivity() = checkHost(FragmentProbeActivity::class.java)

    private fun checkHost(host: Class<out Activity>) {
        ActivityScenario.launch<Activity>(Intent(context, host)).use { scenario ->
            checkPhase(Build.VERSION.SDK_INT >= 34, "startup")
            click("Disable protection")
            await("Dart observed disabled host") { tool().tree().contains("filtered=false") }
            clearEvents()
            checkPhase(false, "disabled")
            click("Enable protection")
            await("Dart observed enabled host") {
                tool().tree().contains("filtered=${Build.VERSION.SDK_INT >= 34}")
            }
            Thread.sleep(750)
            clearEvents()
            checkPhase(Build.VERSION.SDK_INT >= 34, "enabled")
            clearEvents()
            scenario.recreate()
            checkPhase(Build.VERSION.SDK_INT >= 34, "recreated")
        }
    }

    private fun tool() = ToolProbeService.instance!!
    private fun nonTool() = NonToolProbeService.instance!!
    private fun clearEvents() { tool().events.clear(); nonTool().events.clear() }
    private fun secret(value: String) = value.contains("seed-probe") || value.contains("private-probe")

    private fun checkPhase(protected: Boolean, phase: String) {
        await("$phase: tool can query Flutter semantics") {
            val tree = tool().tree()
            tree.contains("public-probe") && tree.contains("seed-probe") && tree.contains("private-probe")
        }
        await("$phase: tool receives input events") {
            tool().events.any { it.contains("private-probe") }
        }
        if (!protected) await("$phase: non-tool positive control") {
            secret(nonTool().tree()) && nonTool().events.any { it.contains("private-probe") }
        }
        repeat(10) {
            val toolTree = tool().tree()
            val otherTree = nonTool().tree()
            assertFalse("$phase: fallback visible to tool", toolTree.contains("fallback-probe"))
            assertFalse("$phase: fallback visible to non-tool", otherTree.contains("fallback-probe"))
            for (service in listOf(tool(), nonTool())) {
                assertFalse("$phase: fallback event leaked", service.events.any { it.contains("fallback-probe") })
            }
            if (protected) {
                assertFalse("$phase: non-tool queried secrets: $otherTree", secret(otherTree))
                assertFalse("$phase: non-tool received secret events", nonTool().events.any(::secret))
            } else {
                assertTrue("$phase: non-tool queried public UI", otherTree.contains("public-probe"))
                assertTrue("$phase: non-tool queried seed", otherTree.contains("seed-probe"))
                assertTrue("$phase: non-tool queried input", otherTree.contains("private-probe"))
            }
            Thread.sleep(100)
        }
    }

    private fun click(label: String) {
        fun find(node: AccessibilityNodeInfo?): Boolean {
            if (node == null) return false
            try {
                if (node.text?.toString() == label || node.contentDescription?.toString() == label) {
                    return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                }
                for (i in 0 until node.childCount) if (find(node.getChild(i))) return true
                return false
            } finally { node.recycle() }
        }
        await("click $label") { find(tool().rootInActiveWindow) }
    }

    private fun await(message: String, predicate: () -> Boolean) {
        val deadline = System.currentTimeMillis() + 20000
        while (System.currentTimeMillis() < deadline) {
            if (predicate()) return
            Thread.sleep(100)
        }
        fail(message)
    }
}
