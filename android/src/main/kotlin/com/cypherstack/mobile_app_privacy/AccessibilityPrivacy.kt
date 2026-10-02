package com.cypherstack.mobile_app_privacy

import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.view.View
import java.util.WeakHashMap

internal class AccessibilityPrivacy {
    private var requested: Boolean? = null
    private var root: View? = null
    private var restoreMode = View.ACCESSIBILITY_DATA_SENSITIVE_AUTO

    @Suppress("DEPRECATION")
    fun attach(activity: Activity) {
        if (Build.VERSION.SDK_INT < 34) return
        val applicationInfo = activity.packageManager.getApplicationInfo(
            activity.packageName, PackageManager.GET_META_DATA
        )
        val activityInfo = activity.packageManager.getActivityInfo(
            activity.componentName, PackageManager.GET_META_DATA
        )
        val configuredMode = activityInfo.metaData?.get(RESTORE_METADATA_KEY)
            ?: applicationInfo.metaData?.get(RESTORE_METADATA_KEY)
        restoreMode = when (configuredMode) {
            null, "auto" -> View.ACCESSIBILITY_DATA_SENSITIVE_AUTO
            "yes" -> View.ACCESSIBILITY_DATA_SENSITIVE_YES
            "no" -> View.ACCESSIBILITY_DATA_SENSITIVE_NO
            else -> throw IllegalArgumentException(
                "$RESTORE_METADATA_KEY must be auto, yes, or no"
            )
        }
        root = activity.window.decorView
        if (requested == null) {
            requested = applicationInfo.metaData?.getBoolean(METADATA_KEY, false) ?: false
        }
        apply()
    }

    fun detach() {
        root = null
    }

    fun setEnabled(enabled: Boolean): Boolean {
        requested = enabled
        apply()
        return isEnabled()
    }

    fun isEnabled(): Boolean = Build.VERSION.SDK_INT >= 34 &&
        root?.isAccessibilityDataSensitive == true

    private fun apply() {
        if (Build.VERSION.SDK_INT < 34) return
        val view = root ?: return
        if (requested == true) {
            if (!overrides.containsKey(view)) overrides[view] = restoreMode
            view.setAccessibilityDataSensitive(View.ACCESSIBILITY_DATA_SENSITIVE_YES)
        } else {
            val mode = overrides[view] ?: return
            view.setAccessibilityDataSensitive(mode)
            overrides.remove(view)
        }
    }

    companion object {
        const val METADATA_KEY =
            "com.cypherstack.mobile_app_privacy.ACCESSIBILITY_DATA_SENSITIVE"
        const val RESTORE_METADATA_KEY =
            "com.cypherstack.mobile_app_privacy.ACCESSIBILITY_DATA_SENSITIVE_RESTORE_MODE"

        // Main thread only.
        private val overrides = WeakHashMap<View, Int>()
    }
}
