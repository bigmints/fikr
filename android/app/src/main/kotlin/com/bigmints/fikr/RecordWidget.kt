package com.bigmints.fikr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/**
 * AppWidget receiver for Fikr's "Record a Note" home-screen widget.
 *
 * The widget displays a mic button + the title of the last saved note.
 * Tapping the widget fires a deep-link intent (fikr://record) which the
 * Flutter layer intercepts via home_widget's widgetClicked stream and
 * immediately starts the recording flow.
 */
class RecordWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        ids.forEach { id -> updateAppWidget(context, manager, id) }
    }
}

private fun updateAppWidget(
    context: Context,
    manager: AppWidgetManager,
    appWidgetId: Int
) {
    val prefs = context.getSharedPreferences(
        "HomeWidgetPreferences",
        Context.MODE_PRIVATE
    )
    val lastNote = prefs.getString("lastNoteTitle", null)

    val views = RemoteViews(context.packageName, R.layout.record_widget)

    // Set subtitle: last note title or default prompt.
    views.setTextViewText(
        R.id.widget_last_note,
        if (!lastNote.isNullOrBlank()) "Last: $lastNote" else "Tap to record a thought"
    )

    // Build the deep-link PendingIntent.
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("fikr://record")).apply {
        setPackage(context.packageName)
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    val pendingIntent = PendingIntent.getActivity(
        context,
        0,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
    manager.updateAppWidget(appWidgetId, views)
}
