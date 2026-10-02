package com.cypherstack.mobile_app_privacy_example

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Looper
import android.view.View
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import com.cypherstack.mobile_app_privacy.MobileAppPrivacyPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test

class AccessibilityLifecycleTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()

    private fun call(plugin: MobileAppPrivacyPlugin, method: String, value: Any? = null): Any? {
        var response: Any? = "no reply"
        val invoke = Runnable {
            plugin.onMethodCall(MethodCall(method, value?.let { mapOf("enable" to it) }),
                object : MethodChannel.Result {
                    override fun success(result: Any?) { response = result }
                    override fun error(code: String, message: String?, details: Any?) { response = code }
                    override fun notImplemented() { response = "not implemented" }
                })
        }
        if (Looper.myLooper() == Looper.getMainLooper()) invoke.run()
        else instrumentation.runOnMainSync(invoke)
        return response
    }

    private fun binding(activity: Activity): ActivityPluginBinding = Proxy.newProxyInstance(
        ActivityPluginBinding::class.java.classLoader,
        arrayOf(ActivityPluginBinding::class.java)
    ) { _, method, _ -> if (method.name == "getActivity") activity else null } as ActivityPluginBinding

    @Test fun requestsSurviveDetachmentAndReportActualState() {
        val plugin = MobileAppPrivacyPlugin()
        assertEquals(false, call(plugin, "isAccessibilityDataSensitive"))
        assertEquals(false, call(plugin, "setAccessibilityDataSensitive", true))
        val intent = Intent(instrumentation.targetContext, MainActivity::class.java)
        ActivityScenario.launch<MainActivity>(intent).use { scenario ->
            scenario.onActivity { activity ->
                if (Build.VERSION.SDK_INT >= 34) activity.window.decorView
                    .setAccessibilityDataSensitive(View.ACCESSIBILITY_DATA_SENSITIVE_AUTO)
                plugin.onAttachedToActivity(binding(activity))
            }
            assertEquals(Build.VERSION.SDK_INT >= 34, call(plugin, "isAccessibilityDataSensitive"))
            assertEquals(false, call(plugin, "setAccessibilityDataSensitive", false))
            instrumentation.runOnMainSync { plugin.onDetachedFromActivityForConfigChanges() }
            assertEquals(false, call(plugin, "isAccessibilityDataSensitive"))
        }
        ActivityScenario.launch<MainActivity>(intent).use { scenario ->
            scenario.onActivity { activity ->
                if (Build.VERSION.SDK_INT >= 34) activity.window.decorView
                    .setAccessibilityDataSensitive(View.ACCESSIBILITY_DATA_SENSITIVE_AUTO)
                plugin.onReattachedToActivityForConfigChanges(binding(activity))
            }
            assertEquals(false, call(plugin, "isAccessibilityDataSensitive"))
            assertEquals(Build.VERSION.SDK_INT >= 34, call(plugin, "setAccessibilityDataSensitive", true))
            assertEquals(false, call(plugin, "setAccessibilityDataSensitive", false))
            assertEquals("invalid_argument", call(plugin, "setAccessibilityDataSensitive"))
            assertEquals("invalid_argument", call(plugin, "setAccessibilityDataSensitive", "true"))
            instrumentation.runOnMainSync { plugin.onDetachedFromActivity() }
            assertEquals(false, call(plugin, "isAccessibilityDataSensitive"))
        }
    }

    @Test fun disablingPreservesPreexistingHostProtection() {
        val plugin = MobileAppPrivacyPlugin()
        call(plugin, "setAccessibilityDataSensitive", false)
        val intent = Intent(instrumentation.targetContext, YesPolicyProbeActivity::class.java)
        ActivityScenario.launch<YesPolicyProbeActivity>(intent).use { scenario ->
            scenario.onActivity { activity ->
                if (Build.VERSION.SDK_INT >= 34) activity.window.decorView
                    .setAccessibilityDataSensitive(View.ACCESSIBILITY_DATA_SENSITIVE_YES)
                plugin.onAttachedToActivity(binding(activity))
            }
            assertEquals(Build.VERSION.SDK_INT >= 34, call(plugin, "setAccessibilityDataSensitive", false))
            instrumentation.runOnMainSync { plugin.onDetachedFromActivity() }
        }
    }

    private fun withPolicyHost(host: Class<out Activity>, check: (Activity) -> Unit) {
        assumeTrue(Build.VERSION.SDK_INT >= 34)
        val intent = Intent(instrumentation.targetContext, host)
        ActivityScenario.launch<Activity>(intent).use { scenario ->
            scenario.onActivity { check(it) }
        }
    }

    @Test fun disablingAfterReattachingSameViewRestoresPolicy() =
        withPolicyHost(AutoPolicyProbeActivity::class.java) { activity ->
            val plugin = MobileAppPrivacyPlugin()
            plugin.onAttachedToActivity(binding(activity))
            val view = activity.window.decorView
            assertTrue(view.isAccessibilityDataSensitive)
            plugin.onDetachedFromActivity()
            assertTrue("Departing view stays protected", view.isAccessibilityDataSensitive)
            plugin.onAttachedToActivity(binding(activity))
            assertEquals(false, call(plugin, "setAccessibilityDataSensitive", false))
            plugin.onDetachedFromActivity()
        }

    @Test fun disableWhileDetachedTakesEffectWhenSameViewReturns() =
        withPolicyHost(AutoPolicyProbeActivity::class.java) { activity ->
            val plugin = MobileAppPrivacyPlugin()
            plugin.onAttachedToActivity(binding(activity))
            plugin.onDetachedFromActivityForConfigChanges()
            assertEquals(false, call(plugin, "setAccessibilityDataSensitive", false))
            assertTrue(activity.window.decorView.isAccessibilityDataSensitive)
            plugin.onReattachedToActivityForConfigChanges(binding(activity))
            assertEquals(false, call(plugin, "isAccessibilityDataSensitive"))
            plugin.onDetachedFromActivity()
        }

    @Test fun replacementPluginCanReleaseOverrideOnSameView() =
        withPolicyHost(AutoPolicyProbeActivity::class.java) { activity ->
            val first = MobileAppPrivacyPlugin()
            first.onAttachedToActivity(binding(activity))
            first.onDetachedFromActivity()
            val replacement = MobileAppPrivacyPlugin()
            replacement.onAttachedToActivity(binding(activity))
            assertEquals(false, call(replacement, "setAccessibilityDataSensitive", false))
            replacement.onDetachedFromActivity()
        }

    @Test fun explicitNoSurvivesEnableDisableWithObscuredTouchFiltering() =
        withPolicyHost(NoPolicyProbeActivity::class.java) { activity ->
            val view = activity.window.decorView
            view.filterTouchesWhenObscured = true
            view.setAccessibilityDataSensitive(View.ACCESSIBILITY_DATA_SENSITIVE_NO)
            val plugin = MobileAppPrivacyPlugin()
            plugin.onAttachedToActivity(binding(activity))
            assertTrue(view.isAccessibilityDataSensitive)
            assertEquals(false, call(plugin, "setAccessibilityDataSensitive", false))
            plugin.onDetachedFromActivity()
        }

    @Test fun inferredYesReturnsToAutoAfterEnableDisable() =
        withPolicyHost(AutoPolicyProbeActivity::class.java) { activity ->
            val view = activity.window.decorView
            view.filterTouchesWhenObscured = true
            view.setAccessibilityDataSensitive(View.ACCESSIBILITY_DATA_SENSITIVE_AUTO)
            val plugin = MobileAppPrivacyPlugin()
            plugin.onAttachedToActivity(binding(activity))
            assertEquals(true, call(plugin, "setAccessibilityDataSensitive", false))
            view.filterTouchesWhenObscured = false
            assertFalse("AUTO must still respond to host policy changes", view.isAccessibilityDataSensitive)
            plugin.onDetachedFromActivity()
        }

    @Test fun explicitYesSurvivesEnableDisable() =
        withPolicyHost(YesPolicyProbeActivity::class.java) { activity ->
            val view = activity.window.decorView
            view.setAccessibilityDataSensitive(View.ACCESSIBILITY_DATA_SENSITIVE_YES)
            val plugin = MobileAppPrivacyPlugin()
            plugin.onAttachedToActivity(binding(activity))
            assertEquals(true, call(plugin, "setAccessibilityDataSensitive", false))
            view.filterTouchesWhenObscured = true
            view.filterTouchesWhenObscured = false
            assertTrue(view.isAccessibilityDataSensitive)
            plugin.onDetachedFromActivity()
        }
}
