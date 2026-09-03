package com.example.girinori

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

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
                    val route = call.argument<String>("route") ?: ""
                    val stations =
                        call.argument<List<Map<String, String?>>>("stations")
                            ?: emptyList()

                    val stationsJson = JSONArray().apply {
                        stations.forEach { station ->
                            put(
                                org.json.JSONObject().apply {
                                    station.forEach { (key, value) ->
                                        put(key, value)
                                    }
                                }
                            )
                        }
                    }.toString()

                    val prefs = getSharedPreferences(
                        "route_widget",
                        Context.MODE_PRIVATE
                    )

                    prefs.edit()
                        .putString("route", route)
                        .putString("stations", stationsJson)
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

        val componentName = ComponentName(
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