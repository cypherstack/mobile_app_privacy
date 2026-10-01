package com.cypherstack.mobile_app_privacy

import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.view.View

internal class AccessibilityPrivacy {
    private var requested: Boolean? = null
    private var root: View? = null
    private var originalMode: Int? = null
    private var applied = false

    fun attach(activity: Activity) {
        if (Build.VERSION.SDK_INT < 34) return
        val view = activity.window.decorView
        root = view
        applied = false
        originalMode = if (view.isAccessibilityDataSensitive) {
            View.ACCESSIBILITY_DATA_SENSITIVE_YES
        } else {
            View.ACCESSIBILITY_DATA_SENSITIVE_AUTO
        }
        if (requested == null) {
            @Suppress("DEPRECATION")
            val info = activity.packageManager.getApplicationInfo(
                activity.packageName, PackageManager.GET_META_DATA
            )
            requested = info.metaData?.getBoolean(METADATA_KEY, false) ?: false
        }
        apply()
    }

    fun detach() {
        root = null
        originalMode = null
        applied = false
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
        if (requested != true && !applied) return
        root?.setAccessibilityDataSensitive(if (requested == true) {
            View.ACCESSIBILITY_DATA_SENSITIVE_YES
        } else {
            originalMode ?: View.ACCESSIBILITY_DATA_SENSITIVE_AUTO
        })
        applied = requested == true
    }

    companion object {
        const val METADATA_KEY =
            "com.cypherstack.mobile_app_privacy.ACCESSIBILITY_DATA_SENSITIVE"
    }
}
