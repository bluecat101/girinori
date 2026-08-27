package com.example.girinori

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "girinori/widget"
    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val route     = call.argument<String>("route") ?: ""
                    val departure = call.argument<String>("departure") ?: ""
                    val arrival   = call.argument<String>("arrival") ?: ""
                    val prefs     = getSharedPreferences(
                        "route_widget",
                        Context.MODE_PRIVATE
                    )

                    prefs.edit()
                        .putString("route", route)
                        .putString("departure", departure)
                        .putString("arrival", arrival)
                        .apply()
                    updateAllWidgets()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun updateAllWidgets() {
        val manager = AppWidgetManager.getInstance(this)
        val componentName =ComponentName(
                this,
                RouteWidgetProvider::class.java
            )

        val ids = manager.getAppWidgetIds(componentName)
        for (id in ids) {
            RouteWidgetProvider.updateWidget(
                this,
                manager,
                id
            )
        }
    }
    
}