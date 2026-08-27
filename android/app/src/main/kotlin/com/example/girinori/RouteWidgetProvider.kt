package com.example.girinori

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class RouteWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(
                context,
                appWidgetManager,
                appWidgetId
            )
        }
    }

    companion object {

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // SharedPreferencesからFlutter側で保存したデータを取得
            val prefs = context.getSharedPreferences(
                "route_widget",
                Context.MODE_PRIVATE
            )

            val route = prefs.getString(
                "route",
                "ルート未設定"
            ) ?: "ルート未設定"

            val departure = prefs.getString(
                "departure",
                "--:--"
            ) ?: "--:--"

            val arrival = prefs.getString(
                "arrival",
                "--:--"
            ) ?: "--:--"

            // WidgetのViewを取得
            val views = RemoteViews(
                context.packageName,
                R.layout.route_widget
            )

            // データを表示
            views.setTextViewText(
                R.id.widget_route,
                route
            )

            views.setTextViewText(
                R.id.widget_departure,
                "$departure 発"
            )

            views.setTextViewText(
                R.id.widget_arrival,
                "$arrival 着"
            )

            // Widgetを更新
            appWidgetManager.updateAppWidget(
                appWidgetId,
                views
            )
        }
    }
}