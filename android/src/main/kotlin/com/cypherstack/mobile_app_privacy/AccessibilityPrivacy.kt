package com.cypherstack.mobile_app_privacy

import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.view.View
import java.util.WeakHashMap

internal class AccessibilityPrivacy {
    private var requested: Boolean? = null
    private var root: View? = null
    // A token avoids retaining this instance (and its root) through the weak map.
    private val owner = Any()

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
        val restoreMode = when (configuredMode) {
            null, "auto" -> View.ACCESSIBILITY_DATA_SENSITIVE_AUTO
            "yes" -> View.ACCESSIBILITY_DATA_SENSITIVE_YES
            "no" -> View.ACCESSIBILITY_DATA_SENSITIVE_NO
            else -> throw IllegalArgumentException(
                "$RESTORE_METADATA_KEY must be auto, yes, or no"
            )
        }
        val view = activity.window.decorView
        if (root !== view) detach()
        root = view
        overrides.getOrPut(view) { ViewState(restoreMode) }
        if (requested == null) {
            requested = applicationInfo.metaData?.getBoolean(METADATA_KEY, false) ?: false
        }
        apply()
    }

    fun detach() {
        root?.let { view ->
            overrides[view]?.let { state ->
                state.owners.remove(owner)
                if (state.owners.isNotEmpty()) {
                    reconcile(view, state)
                } else if (!state.applied) {
                    overrides.remove(view)
                }
                // With no attached owners, keep departing views protected and
                // retain their restoration mode for a later attachment.
            }
        }
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
        val state = overrides[view] ?: return
        state.owners[owner] = requested == true
        reconcile(view, state)
    }

    private fun reconcile(view: View, state: ViewState) {
        if (Build.VERSION.SDK_INT < 34) return
        if (state.owners.values.any { it }) {
            view.setAccessibilityDataSensitive(View.ACCESSIBILITY_DATA_SENSITIVE_YES)
            state.applied = true
        } else if (state.applied) {
            view.setAccessibilityDataSensitive(state.restoreMode)
            state.applied = false
        }
    }

    private class ViewState(val restoreMode: Int) {
        val owners = mutableMapOf<Any, Boolean>()
        var applied = false
    }

    companion object {
        const val METADATA_KEY =
            "com.cypherstack.mobile_app_privacy.ACCESSIBILITY_DATA_SENSITIVE"
        const val RESTORE_METADATA_KEY =
            "com.cypherstack.mobile_app_privacy.ACCESSIBILITY_DATA_SENSITIVE_RESTORE_MODE"

        // Main thread only.
        private val overrides = WeakHashMap<View, ViewState>()
    }
}
